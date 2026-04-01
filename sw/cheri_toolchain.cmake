# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set(CHERI_FLAGS -march=rv64imac_zcherihybrid -mabi=l64pc128 -mcmodel=medany)
set(VANILLA_FLAGS -march=rv64imac -mabi=lp64 -mcmodel=medany)

set(CMAKE_SYSTEM_NAME Generic)

if (DEFINED ENV{CHERI_LLVM_BIN})
    set(CMAKE_CXX_COMPILER "$ENV{CHERI_LLVM_BIN}/clang++")
    set(CMAKE_C_COMPILER   "$ENV{CHERI_LLVM_BIN}/clang")
    set(CMAKE_ASM_COMPILER "$ENV{CHERI_LLVM_BIN}/clang")
    set(CMAKE_OBJCOPY      "$ENV{CHERI_LLVM_BIN}/llvm-objcopy")
    set(CMAKE_OBJDUMP      "$ENV{CHERI_LLVM_BIN}/llvm-objdump")
else()
    set(CMAKE_CXX_COMPILER clang++)
    set(CMAKE_C_COMPILER   clang)
    set(CMAKE_ASM_COMPILER clang)
    set(CMAKE_OBJCOPY      llvm-objcopy)
    set(CMAKE_OBJDUMP      llvm-objdump)
endif()

set(CMAKE_ASM_COMPILER_TARGET riscv64-unknown-elf)
set(CMAKE_C_COMPILER_TARGET   riscv64-unknown-elf)
set(CMAKE_CXX_COMPILER_TARGET riscv64-unknown-elf)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED TRUE)

# linkerscript to use
set(LDS_DIR "${CMAKE_SOURCE_DIR}/device/lib/boot")
set(LDS "${LDS_DIR}/mocha.ld")

string(CONCAT CMAKE_CXX_FLAGS_INIT
  "-std=c++20 -O0 -g"
  " -ffreestanding -static"
  " -fno-builtin -fno-exceptions -fno-c++-static-destructors -fno-rtti"
  " -Wall -Wextra"
)

string(CONCAT CMAKE_C_FLAGS_INIT
  "-std=c99 -O0 -g"
  " -ffreestanding -static"
  " -fno-builtin"
  " -Wall -Wextra"
)

set(CMAKE_ASM_FLAGS_INIT "")

set(CMAKE_EXE_LINKER_FLAGS_INIT
    "-nodefaultlibs"
)
