#
# This file is part of AtomVM.
#
# Copyright 2018 Fred Dushin <fred@dushin.net>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
#

project(test_eavmlib)

include(BuildErlang)

set(ERLANG_MODULES
    test_dir
    test_file
    test_ahttp_client
    test_http_server
    test_mdns
    test_port
    test_timer_manager
)

pack_archive(test_eavmlib_lib ${ERLANG_MODULES})
pack_test(test_eavmlib eavmlib estdlib etest)
