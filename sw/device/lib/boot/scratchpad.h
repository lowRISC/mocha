// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#if !defined(__ASSEMBLER__)

#include <stdint.h>
#if defined(__riscv_zcherihybrid)
#include <cheriintrin.h>
#endif /* defined(__riscv_zcherihybrid) */

struct scratchpad {
#if defined(__riscv_zcherihybrid)
    uintptr_t trap_stack;
#endif /* defined(__riscv_zcherihybrid) */
    uintptr_t saved_sp;
    uintptr_t saved_a1;
};

#endif /* !defined(__ASSEMBLER__) */

#if defined(__riscv_zcherihybrid)
#define SCRATCHPAD_TRAP_STACK_OFFSET 0
#define SCRATCHPAD_SAVED_SP_OFFSET   16
#define SCRATCHPAD_SAVED_A1_OFFSET   32
#define SCRATCHPAD_SIZE              48
#else /* !defined(__riscv_zcherihybrid) */
#define SCRATCHPAD_SAVED_SP_OFFSET 0
#define SCRATCHPAD_SAVED_A1_OFFSET 8
#define SCRATCHPAD_SIZE            16
#endif /* defined(__riscv_zcherihybrid) */

#if !defined(__ASSEMBLER__)

#if defined(__riscv_zcherihybrid)
_Static_assert(__builtin_offsetof(struct scratchpad, trap_stack) == SCRATCHPAD_TRAP_STACK_OFFSET,
               "incorrect struct scratchpad trap_stack offset");
#endif /* defined(__riscv_zcherihybrid) */
_Static_assert(__builtin_offsetof(struct scratchpad, saved_sp) == SCRATCHPAD_SAVED_SP_OFFSET,
               "incorrect struct scratchpad saved_sp offset");
_Static_assert(__builtin_offsetof(struct scratchpad, saved_a1) == SCRATCHPAD_SAVED_A1_OFFSET,
               "incorrect struct scratchpad saved_a1 offset");
_Static_assert(sizeof(struct scratchpad) == SCRATCHPAD_SIZE, "incorrect struct scratchpad size");

#endif /* !defined(__ASSEMBLER__) */
