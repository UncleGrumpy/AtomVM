/*
 * This file is part of AtomVM.
 *
 * Copyright 2017 Davide Bettio <davide@uninstall.it>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
 */

#include "scheduler.h"
#include "debug.h"
#include "list.h"
#include "smp.h"
#include "sys.h"
#include "utils.h"

#ifndef AVM_NO_SMP
#define SMP_SPINLOCK_LOCK(spinlock) smp_spinlock_lock(spinlock)
#define SMP_SPINLOCK_UNLOCK(spinlock) smp_spinlock_unlock(spinlock)
#define SMP_MUTEX_LOCK(mtx) smp_mutex_lock(mtx)
#define SMP_MUTEX_TRYLOCK(mtx) smp_mutex_trylock(mtx)
#define SMP_MUTEX_UNLOCK(mtx) smp_mutex_unlock(mtx)
#else
#define SMP_SPINLOCK_LOCK(spinlock)
#define SMP_SPINLOCK_UNLOCK(spinlock)
#define SMP_MUTEX_LOCK(mtx)
#define SMP_MUTEX_TRYLOCK(mtx) 1
#define SMP_MUTEX_UNLOCK(mtx)
#endif

static void scheduler_timeout_callback(struct TimerListItem *it);

static int update_timer_list(GlobalContext *global)
{
    struct TimerList *tw = &global->timer_list;
    if (timer_list_is_empty(tw)) {
        // Do not fetch the current date if there is no timer
        return -1;
    }
    uint64_t millis_now = sys_millis(global);
    timer_list_next(tw, millis_now, scheduler_timeout_callback);
    if (tw->next_timer == 0) {
        return -1;
    }
    uint64_t wait_timeout = tw->next_timer - millis_now;
    if (wait_timeout > INT_MAX) {
        wait_timeout = INT_MAX;
    }
    return (int) wait_timeout;
}

Context *scheduler_wait(Context *ctx)
{
#ifdef DEBUG_PRINT_READY_PROCESSES
    debug_print_processes_list(global->ready_processes);
#endif
    GlobalContext *global = ctx->global;
    SMP_SPINLOCK_LOCK(&global->processes_spinlock);
    context_update_flags(ctx, ~Running, NoFlags);
    // Remove from running list, but do not remove from ready list.
    if (!context_get_flags(ctx, Ready)) {
        list_remove(&ctx->processes_list_head);
        list_append(&global->waiting_processes, &ctx->processes_list_head);
    }
    SMP_SPINLOCK_UNLOCK(&global->processes_spinlock);

    return scheduler_run(global);
}

static void scheduler_process_native_signal_messages(Context *ctx)
{
    // This mirrors PROCESS_SIGNAL_MESSAGES macro of emulated processes, but
    // for native processes.
    MailboxMessage *signal_message = mailbox_process_outer_list(&ctx->mailbox);
    while (signal_message) {
        if (signal_message->type == KillSignal) {
            struct TermSignal *kill_signal = CONTAINER_OF(signal_message, struct TermSignal, base);
            context_process_kill_signal(ctx, kill_signal);
        } else if (signal_message->type == ProcessInfoRequestSignal) {
            struct BuiltInAtomRequestSignal *request_signal
                = CONTAINER_OF(signal_message, struct BuiltInAtomRequestSignal, base);
            context_process_process_info_request_signal(ctx, request_signal);
        }
        MailboxMessage *next = signal_message->next;
        mailbox_destroy_signal_message(signal_message);
        signal_message = next;
    }
}

static Context *scheduler_run0(GlobalContext *global)
{
    // This function should return a new process to run.
    // If running_schedulers is greater than online_schedulers, take the
    // opportunity to end the scheduler, in which case the function returns
    // NULL
    Context *result = NULL;

#ifndef AVM_NO_SMP
    SMP_MUTEX_LOCK(global->schedulers_mutex);
    bool is_waiting = !global->waiting_scheduler;
    if (is_waiting) {
        global->waiting_scheduler = true;
    }
    bool main_thread = smp_is_main_thread(global);
#endif
    do {
#ifndef AVM_NO_SMP
        // We keep every scheduler threads but one in condition variable.
        // `is_waiting` holds for the one that leaves this loop and it
        // processes the timer, the scheduling and the system events in this
        // order. If a process is to be scheduled (native or not), it signals
        // the condition variable so another thread can take over.
        // When there is nothing to do, the scheduler thread that runs the
        // timer (for which is_waiting is true) waits into `sys_poll_events`
        // until the timer expires or it is signaled with `sys_signal`.
        do {
            if (main_thread && global->scheduler_stop_all) {
                while (global->running_schedulers > 1) {
                    // Wake a thread and join it.
                    if (is_waiting) {
                        global->waiting_scheduler = false;
                    } else {
                        sys_signal(global);
                    }
                    smp_condvar_signal(global->schedulers_cv);
                    smp_condvar_wait(global->schedulers_cv, global->schedulers_mutex);
                }
                global->running_schedulers = 0;
                global->waiting_scheduler = false;
                SMP_MUTEX_UNLOCK(global->schedulers_mutex);
                return NULL;
            }
            if (!main_thread
                && (global->scheduler_stop_all
                    || global->running_schedulers > global->online_schedulers)) {
                global->running_schedulers--;
                if (is_waiting) {
                    global->waiting_scheduler = false;
                } else {
                    sys_signal(global);
                }
                smp_condvar_signal(global->schedulers_cv);
                SMP_MUTEX_UNLOCK(global->schedulers_mutex);
                return NULL;
            }
            if (!is_waiting) {
                // Before entering the condition variable, signal the poll events
                // so the thread polling on events can check the ready queue.
                sys_signal(global);
                smp_condvar_wait(global->schedulers_cv, global->schedulers_mutex);
                is_waiting = !global->waiting_scheduler;
                if (is_waiting) {
                    global->waiting_scheduler = true;
                }
            }
        } while (!is_waiting);
        SMP_MUTEX_UNLOCK(global->schedulers_mutex);
#else
        if (global->scheduler_stop_all) {
            return NULL;
        }
#endif
        // Only one scheduler is running in this section, using the
        // condition variable. It nevertheless needs to wait on the timer_mutex
        // as the timer wheel can be modified by another process.
        SMP_SPINLOCK_LOCK(&global->timer_spinlock);
        int32_t wait_timeout = update_timer_list(global);
        SMP_SPINLOCK_UNLOCK(&global->timer_spinlock);

        SMP_SPINLOCK_LOCK(&global->processes_spinlock);
        // Pick first ready which is not running.
        struct ListHead *next_ready = list_first(&global->ready_processes);
        while (next_ready != &global->ready_processes) {
            result = GET_LIST_ENTRY(next_ready, Context, processes_list_head);
            if (!(result->flags & Running)) {
                list_remove(next_ready);
                context_update_flags(result, ~Ready, Running);
                if (result->native_handler) {
                    // Native handlers are marked as waiting
                    list_append(&global->waiting_processes, next_ready);
                } else {
                    list_append(&global->running_processes, next_ready);
                }
                break;
            }
            next_ready = next_ready->next;
            result = NULL;
        }
        SMP_SPINLOCK_UNLOCK(&global->processes_spinlock);

        if (result == NULL && !global->scheduler_stop_all) {
            sys_poll_events(global, wait_timeout);
        } else {
            sys_poll_events(global, SYS_POLL_EVENTS_DO_NOT_WAIT);
        }
        SMP_MUTEX_LOCK(global->schedulers_mutex);
    } while (result == NULL);

#ifndef AVM_NO_SMP
    global->waiting_scheduler = false;
    smp_condvar_signal(global->schedulers_cv);
    SMP_MUTEX_UNLOCK(global->schedulers_mutex);
#endif

    return result;
}

Context *scheduler_run(GlobalContext *global)
{
    // Outer loop to process native contexts.
    Context *result = NULL;
    do {
        result = scheduler_run0(global);
        if (result == NULL) {
            break;
        }

        if (result->native_handler) {
            // process signal messages and also empty outer list to inner list.
            scheduler_process_native_signal_messages(result);
            if (!(result->flags & Killed)) {
                if (result->native_handler(result)) {
                    context_update_flags(result, ~Running, NoFlags);
                } else {
                    scheduler_terminate(result);
                }
            }
            result = NULL; // Schedule next process (native or not)
        }
    } while (result == NULL);
    return result;
}

Context *scheduler_next(GlobalContext *global, Context *c)
{
    c->reductions += DEFAULT_REDUCTIONS_AMOUNT;

    // Remove c from running and append it at the end of ready list
    // c could already be in ready queue, if it received a message.
    SMP_SPINLOCK_LOCK(&global->processes_spinlock);
    list_remove(&c->processes_list_head);
    list_append(&global->ready_processes, &c->processes_list_head);
    context_update_flags(c, ~Running, NoFlags);
    SMP_SPINLOCK_UNLOCK(&global->processes_spinlock);

    // Schedule.
    return scheduler_run(global);
}

static void scheduler_make_ready(Context *ctx)
{
    GlobalContext *global = ctx->global;
    SMP_SPINLOCK_LOCK(&global->processes_spinlock);
    if (context_get_flags(ctx, Killed)) {
        SMP_SPINLOCK_UNLOCK(&global->processes_spinlock);
        return;
    }
    list_remove(&ctx->processes_list_head);
#ifndef AVM_NO_SMP
    bool waiting_scheduler = global->waiting_scheduler;
    if (!waiting_scheduler) {
        // Start a new scheduler if none are going to take this process.
        if (SMP_MUTEX_TRYLOCK(global->schedulers_mutex)) {
            if (global->running_schedulers > 0
                && global->running_schedulers < global->online_schedulers
                && !context_get_flags(ctx, Running)) {
                global->running_schedulers++;
                smp_scheduler_start(global);
            }
            SMP_MUTEX_UNLOCK(global->schedulers_mutex);
        }
    }
#endif
    // Move to ready queue (from waiting or running)
    // The process may be running (it would be signaled), so mark it
    // as ready
    context_update_flags(ctx, ~NoFlags, Ready);
    list_append(&global->ready_processes, &ctx->processes_list_head);
    SMP_SPINLOCK_UNLOCK(&global->processes_spinlock);
#ifndef AVM_NO_SMP
    if (waiting_scheduler) {
        sys_signal(global);
    }
#endif
}

void scheduler_init_ready(Context *c)
{
    scheduler_make_ready(c);
}

void scheduler_signal_message(Context *c)
{
    scheduler_make_ready(c);
}

void scheduler_terminate(Context *ctx)
{
    SMP_SPINLOCK_LOCK(&ctx->global->processes_spinlock);
    context_update_flags(ctx, ~NoFlags, Killed);
    list_remove(&ctx->processes_list_head);
    SMP_SPINLOCK_UNLOCK(&ctx->global->processes_spinlock);
    if (!ctx->leader) {
        context_destroy(ctx);
    }
}

void scheduler_stop_all(GlobalContext *global)
{
    global->scheduler_stop_all = true;
#ifndef AVM_NO_SMP
    sys_signal(global);
#endif
}

static void scheduler_timeout_callback(struct TimerListItem *it)
{
    Context *ctx = GET_LIST_ENTRY(it, Context, timer_list_head);
    context_update_flags(ctx, ~WaitingTimeout, WaitingTimeoutExpired);
    scheduler_make_ready(ctx);
}

void scheduler_set_timeout(Context *ctx, uint32_t timeout)
{
    GlobalContext *glb = ctx->global;
    uint64_t millis_now = sys_millis(glb);
    uint64_t expiry = millis_now + timeout;

    context_update_flags(ctx, ~NoFlags, WaitingTimeout);
    struct TimerList *tw = &glb->timer_list;
    struct TimerListItem *twi = &ctx->timer_list_head;
    timer_list_item_init(twi, expiry);

    SMP_SPINLOCK_LOCK(&glb->timer_spinlock);
    timer_list_insert(tw, twi);
    SMP_SPINLOCK_UNLOCK(&glb->timer_spinlock);

#ifndef AVM_NO_SMP
    if (glb->waiting_scheduler) {
        sys_signal(glb);
    }
#endif
}

void scheduler_cancel_timeout(Context *ctx)
{
    GlobalContext *glb = ctx->global;

    context_update_flags(ctx, ~(WaitingTimeout | WaitingTimeoutExpired), NoFlags);

    struct TimerList *tw = &glb->timer_list;

    SMP_SPINLOCK_LOCK(&glb->timer_spinlock);
    timer_list_remove(tw, &ctx->timer_list_head);
    SMP_SPINLOCK_UNLOCK(&glb->timer_spinlock);
}
