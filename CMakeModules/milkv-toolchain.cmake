#
# This file is part of AtomVM.
#
# Copyright 2018 Riccardo Binetti <rbino@gmx.com>
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


# Use milkv gcc toolchain for crosscompiling
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR c906fdv)

if (NOT EXISTS $ENV{SYSROOT})
    message(FATAL_ERROR "Milkv-Duo SDK not setup! SYSROOT must point to duo-sdk/rootfs directory.")
endif()

if (NOT EXISTS $ENV{TOOLCHAIN_PREFIX}gcc)
    message(FATAL_ERROR "Milkv-Duo SDK not setup! TOOLCHAIN_PREFIX not set to duo-sdk toolchain prefix.")
endif()

set(CMAKE_C_COMPILER $ENV{TOOLCHAIN_PREFIX}gcc)
set(CMAKE_CXX_COMPILER $ENV{TOOLCHAIN_PREFIX}g++)
set(CMAKE_OBJCOPY $ENV{TOOLCHAIN_PREFIX}objcopy)
set(CMAKE_LINKER $ENV{TOOLCHAIN_PREFIX}ld)
set(TOOLCHAIN_SIZE $ENV{TOOLCHAIN_PREFIX}size)

set(CMAKE_FIND_ROOT_PATH $ENV{SYSROOT})

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

set(CMAKE_LDFLAGS ${LDFLAGS} "-L$ENV{SYSROOT} -L$ENV{SYSROOT}/../riscv64-linux-musl-x86_64")

set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
