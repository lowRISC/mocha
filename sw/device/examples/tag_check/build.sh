# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
clang -target riscv64-unknown-elf -march=rv64ic_zcherihybrid -g -mabi=l64pc128 -cheri -static -ffreestanding -Wall -Wextra -c tag_check.S -o tag_check.o
ld.lld -nostdlib -Tlink.ld tag_check.o -o tag_check.elf
llvm-objdump -d tag_check.elf > tag_check.dump
