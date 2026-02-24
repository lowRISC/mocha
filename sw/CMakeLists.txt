# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

cmake_minimum_required(VERSION 4.1)

if(NOT DEFINED CMAKE_TOOLCHAIN_FILE)
    set(CMAKE_TOOLCHAIN_FILE "${CMAKE_CURRENT_SOURCE_DIR}/cheri_toolchain.cmake")
endif()

project(mocha_sw LANGUAGES C CXX ASM)

# Enable CTest
enable_testing()

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_subdirectory(device)
