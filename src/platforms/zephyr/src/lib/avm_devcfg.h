/* This file is part of AtomVM.
 *
 * Copyright 2023 Winford (Uncle Grumpy) <winford@object.stream>
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

#ifndef _AVM_DEVCFG_H_
#define _AVM_DEVCFG_H_

#include <autoconf.h>
#include <devicetree_generated.h>
// #include <zephyr/storage/flash_map.h>

#define AVM_ADDRESS FIXED_PARTITION_OFFSET(app_partition)
#define APP_MAX_SIZE FIXED_PARTITION_SIZE(app_partition)

#endif /* _AVM_DEVCFG_H_ */
