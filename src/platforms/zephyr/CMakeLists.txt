#
# This file is part of AtomVM.
#
# Copyright 2023 Winford (Uncle Grumpy) <winford@object.stream>
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

cmake_minimum_required (VERSION 3.13)
set(CMAKE_C_STANDARD_REQUIRED YES)
set(CMAKE_CXX_STANDARD_REQUIRED YES)
# Enforce to disable any compiler-specific extensions
set(CMAKE_C_EXTENSIONS NO)
set(CMAKE_CXX_EXTENSIONS NO)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../../CMakeModules")

if (NOT BOARD)
    message(FATAL_ERROR "No BOARD specified for device config generator")
endif ()

find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
set(AVM_ZEPHYR_BUILD ON)
set_property(GLOBAL PROPERTY AVM_ZEPHYR_BUILD ON)
set_property(TARGET app PROPERTY CSTD 11)
set_property(GLOBAL PROPERTY CSTD c11)

project(AtomVM LANGUAGES C)

set(AVM_PEDANTIC_WARNINGS OFF)

if (CONFIG_ATOMVM_DISABLE_SMP)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DAVM_NO_SMP")
endif()

if (CONFIG_AVM_CREATE_STACKTRACES)
    set(AVM_CREATE_STACKTRACES on)
endif()

if (CONFIG_AVM_USE_32BIT_FLOAT)
    set(AVM_USE_32BIT_FLOAT on)
endif()

if (CONFIG_AVM_VERBOSE_ABORT)
    set(AVM_VERBOSE_ABORT on)
endif()

if (CONFIG_REBOOT_ON_NOT_OK)
    add_compile_definitions(CONFIG_REBOOT_ON_NOT_OK)
endif()

    # Configure logging
if (CONFIG_AVM_LOG_DISABLE)
    add_compile_definitions(AVM_LOG_DISABLE)
elseif (CONFIG_AVM_LOG_LEVEL_MAX)
    set(AVM_LOG_LEVEL_MAX ${CONFIG_AVM_LOG_LEVEL_MAX} CACHE STRING "AtomVM max log level")
elseif (CONFIG_LOG_NONE)
    add_compile_definitions(AVM_LOG_DISABLE)
elseif (CONFIG_LOG_ERROR)
    set(AVM_LOG_LEVEL_MAX LOG_ERROR CACHE STRING "AtomVM max log level")
elseif (CONFIG_LOG_WARN)
    set(AVM_LOG_LEVEL_MAX LOG_WARN CACHE STRING "AtomVM max log level")
elseif (CONFIG_LOG_INFO)
    set(AVM_LOG_LEVEL_MAX LOG_INFO CACHE STRING "AtomVM max log level")
elseif (CONFIG_LOG_DEBUG)
    set(AVM_LOG_LEVEL_MAX LOG_DEBUG CACHE STRING "AtomVM max log level")
else()
    set(AVM_LOG_LEVEL_MAX LOG_INFO CACHE STRING "AtomVM max log level")
endif()
if (AVM_LOG_LEVEL_MAX)
    set_property(CACHE AVM_LOG_LEVEL_MAX PROPERTY STRINGS LOG_NONE LOG_ERROR LOG_WARN LOG_INFO LOG_DEBUG)
    add_compile_definitions(AVM_LOG_LEVEL_MAX=${AVM_LOG_LEVEL_MAX})
endif()
if (CONFIG_AVM_ENABLE_LOG_COLOR)
    add_compile_definitions(ENABLE_LOG_COLOR)
endif()
if (CONFIG_AVM_ENABLE_LOG_LINES)
    add_compile_definitions(ENABLE_LOG_LINE_INFO)
endif()

set(
    PLATFORM_LIB_SUFFIX
    ${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR}
)

# Specify output executable
target_sources(app PRIVATE src/main.c)
target_include_directories(app PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src/lib
    ${CMAKE_CURRENT_BINARY_DIR}/libAtomVM
    ${CMAKE_CURRENT_SOURCE_DIR}/../../libAtomVM
    ${CMAKE_BINARY_DIR}/zephyr/include/generated
)

add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../../libAtomVM libAtomVM)
target_link_libraries(app PUBLIC libAtomVM)

add_subdirectory(src/lib)
target_link_libraries(app PUBLIC libAtomVM${PLATFORM_LIB_SUFFIX})

if(CMAKE_COMPILER_IS_GNUCC)
    target_compile_options(app PUBLIC -Wall -Wextra -ggdb)
endif()

message("----------------------------------------")
message(STATUS "System name  : ${CMAKE_SYSTEM_NAME}")
message(STATUS "Board        : ${BOARD}")
message(STATUS "Processor    : ${CMAKE_SYSTEM_PROCESSOR}")
message(STATUS "CPU cores    : ${CONFIG_MP_MAX_NUM_CPUS}")
message("--------Device Configuration Info-------")
message(STATUS "Clock Hz     : ${CONFIG_SYS_CLOCK_HW_CYCLES_PER_SEC}")
if (CONFIG_FLASH_SIZE)
message(STATUS "Flash Size   : ${CONFIG_FLASH_SIZE} KiB")
endif()
message("---------Build Configuration------------")
message(STATUS "Zephyr build : ${AVM_ZEPHYR_BUILD}")
message(STATUS "Log Level    : ${AVM_LOG_LEVEL_MAX}")
message(STATUS "Color Logs   : ${CONFIG_AVM_ENABLE_LOG_COLOR}")
message(STATUS "Log all lines: ${CONFIG_AVM_ENABLE_LOG_LINES}")
message(STATUS "Stactraces   : ${CONFIG_AVM_CREATE_STACKTRACES}")
message(STATUS "Verbose abort: ${CONFIG_AVM_VERBOSE_ABORT}")
message(STATUS "Error Reboot : ${CONFIG_REBOOT_ON_NOT_OK}")
message(STATUS "SMP disabled : ${CONFIG_ATOMVM_DISABLE_SMP}")
message(STATUS "32-Bit Floats: ${AVM_USE_32BIT_FLOAT}")
message(STATUS "Sim Flash    : ${CONFIG_FLASH_SIMULATOR}")
