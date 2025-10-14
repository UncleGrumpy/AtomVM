%
% This file is part of AtomVM.
%
% Copyright 2021 Davide Bettio <davide@uninstall.it>
%
% Licensed under the Apache License, Version 2.0 (the "License");
% you may not use this file except in compliance with the License.
% You may obtain a copy of the License at
%
%    http://www.apache.org/licenses/LICENSE-2.0
%
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS,
% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
% See the License for the specific language governing permissions and
% limitations under the License.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%

-module(supervisor).

-behavior(gen_server).

-export([start_link/2, start_link/3]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(RESTARTING(OldPid), {restarting, OldPid}).

-record(child, {pid = undefined, id, mfargs, restart_type, shutdown, child_type, modules = []}).
-record(state, {name = undefined, strategy = one_for_one, intensity, period, children = []}).

start_link(Module, Args) ->
    gen_server:start_link(?MODULE, {Module, Args, undefined}, []).

start_link(SupName, Module, Args) ->
    gen_server:start_link(SupName, ?MODULE, {Module, Args, SupName}, []).

init({Mod, Args, SupName}) ->
    erlang:process_flag(trap_exit, true),
    case Mod:init(Args) of
        {ok, {{Strategy, _Intensity, _Period}, StartSpec}} ->
            State = init_state(StartSpec, #state{}),
            NewChildren = start_children(State#state.children, []),
            {ok, State#state{name = SupName, strategy = Strategy, children = NewChildren}};
        Error ->
            {stop, {bad_return, {mod, init, Error}}}
    end.

init_state([{ChildId, MFA, Restart, brutal_kill, Type, Modules} | T], State) ->
    Child =
        #child{
            id = ChildId,
            mfargs = MFA,
            restart_type = Restart,
            shutdown = brutal_kill,
            child_type = Type,
            modules = Modules
        },
    NewChildren = [Child | State#state.children],
    init_state(T, #state{children = NewChildren});
init_state([], State) ->
    State#state{children = lists:reverse(State#state.children)}.

start_children([Child | T], StartedC) ->
    #child{mfargs = {M, F, Args}} = Child,
    case apply(M, F, Args) of
        {ok, Pid} when is_pid(Pid) ->
            start_children(T, [Child#child{pid = Pid} | StartedC]);
        Error ->
            exit(Error)
    end;
start_children([], StartedC) ->
    StartedC.

restart_child(Pid, Reason, #state{strategy = one_for_one} = State) ->
    Child = lists:keyfind(Pid, #child.pid, State#state.children),

    #child{mfargs = {M, F, Args}} = Child,
    case should_restart(Reason, Child#child.restart_type) of
        true ->
            case apply(M, F, Args) of
                {ok, NewPid} when is_pid(Pid) ->
                    NewChild = Child#child{pid = NewPid},
                    Children = lists:keyreplace(Pid, #child.pid, State#state.children, NewChild),
                    {ok, State#state{children = Children}}
            end;
        false ->
            Children = lists:keydelete(Pid, #child.pid, State#state.children),
            {ok, State#state{children = Children}}
    end;
restart_child(Pid, Reason, #state{strategy = one_for_all} = State) ->
    case lists:keyfind(Pid, #child.pid, State#state.children) of
        false ->
            {ok, State};
        Child ->
            case should_restart(Reason, Child#child.restart_type) of
                true ->
                    Children = lists:keydelete(Pid, #child.pid, State#state.children),
                    case restart_children(Child, Children, Reason) of
                        {ok, Children0} ->
                            {ok, State#state{children = Children0}};
                        _Error ->
                            {stop, shutdown, State}
                    end;
                false ->
                    Children = lists:keyreplace(Pid, #child.pid, State#state.children, Child#child{
                        pid = undefined
                    }),
                    {ok, State#state{children = Children}}
            end
    end.

should_restart(_Reason, permanent) ->
    true;
should_restart(_Reason, temporary) ->
    false;
should_restart(Reason, transient) ->
    case Reason of
        normal ->
            false;
        _any ->
            true
    end.

restart_children(Child, Children, Reason) ->
    {ok, Children1, ErrorList} = terminate_children_return_restart_list(
        Reason, Children, [Child], []
    ),
    case ErrorList of
        [] ->
            NewChildren = start_children(Children1, []),
            {ok, NewChildren};
        ErrorList ->
            % TODO: use logger to report errors
            {error, ErrorList}
    end.

terminate_children_return_restart_list(_Reason, [], NeedsRestart, ErrorList) ->
    {ok, NeedsRestart, ErrorList};
terminate_children_return_restart_list(Reason, [Child | Children], NeedsRestart, ErrorList) ->
    case shutdown_child(Child) of
        {ok, #child{pid = {restarting, _Pid}} = Child0} ->
            terminate_children_return_restart_list(
                Reason, Children, [Child0 | NeedsRestart], ErrorList
            );
        {ok, #child{pid = undefined} = _Child0} ->
            terminate_children_return_restart_list(Reason, Children, NeedsRestart, ErrorList);
        Error ->
            % TODO: log errors
            terminate_children_return_restart_list(Reason, Children, NeedsRestart, [
                {error, Error} | ErrorList
            ])
    end.

shutdown_child(
    #child{
        pid = Pid,
        shutdown = brutal_kill,
        restart_type = Type
    } =
        Child
) when is_pid(Pid) ->
    Mon = monitor(process, Pid),
    exit(Pid, kill),
    receive
        {'DOWN', Mon, process, Pid, Reason0} ->
            stop_monitoring(Pid),
            Child0 =
                case should_restart(Reason0, Type) of
                    true ->
                        Child#child{pid = ?RESTARTING(Pid)};
                    _ ->
                        Child#child{pid = undefined}
                end,
            case Reason0 of
                killed ->
                    {ok, Child0};
                shutdown ->
                    {ok, Child0};
                {shutdown, _} ->
                    {ok, Child0};
                normal ->
                    {ok, Child0};
                Reason1 ->
                    % TODO: log errors
                    {error, {'DOWN', Reason1}}
            end
    end;
shutdown_child(
    #child{
        pid = Pid,
        shutdown = Time,
        restart_type = Type
    } =
        Child
) when is_pid(Pid) ->
    Mon = monitor(process, Pid),
    exit(Pid, shutdown),
    receive
        {'DOWN', Mon, process, Pid, Reason0} ->
            stop_monitoring(Pid),
            Child0 =
                case should_restart(Reason0, Type) of
                    true ->
                        Child#child{pid = ?RESTARTING(Pid)};
                    _ ->
                        Child#child{pid = undefined}
                end,
            case Reason0 of
                killed ->
                    {ok, Child0};
                shutdown ->
                    {ok, Child0};
                {shutdown, _} ->
                    {ok, Child0};
                normal ->
                    {ok, Child0};
                Reason1 ->
                    % TODO: log errors
                    {error, Reason1}
            end
    after Time ->
        exit(Pid, kill),
        receive
            {'DOWN', Mon, process, Pid, Reason0} ->
                ok = stop_monitoring(Pid),
                Child0 =
                    case should_restart(Reason0, Type) of
                        true ->
                            Child#child{pid = ?RESTARTING(Pid)};
                        _ ->
                            Child#child{pid = undefined}
                    end,
                case Reason0 of
                    killed ->
                        {ok, Child0};
                    shutdown ->
                        {ok, Child0};
                    {shutdown, _} ->
                        {ok, Child0};
                    normal ->
                        {ok, Child0};
                    Reason1 ->
                        % TODO: log errors
                        {error, Reason1}
                end
        end
    end;
shutdown_child(Child) ->
    % TODO: log errors
    {error, {no_child, Child}}.

stop_monitoring(Pid) ->
    unlink(Pid),
    receive
        {'EXIT', Pid, _} ->
            ok
    after 0 ->
        ok
    end.

handle_call(_Msg, _from, State) ->
    {noreply, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({'EXIT', Pid, Reason}, State) ->
    case restart_child(Pid, Reason, State) of
        {ok, State1} ->
            {noreply, State1};
        {shutdown, State1} ->
            {stop, shutdown, State1};
        Unexpected ->
            io:format(
                "Supervisor attempt to restart child with pid ~p, for reason ~p, failed unexpectedly (~p)~n",
                [Pid, Reason, Unexpected]
            ),
            {exit, Unexpected, State}
    end;
handle_info(_Msg, State) ->
    %TODO: log unexpected message
    {noreply, State}.
