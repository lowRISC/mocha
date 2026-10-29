// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

// Numeric spellings also work around the RVY compiler release rejecting the
// address-CSR names when assembling an integer-only target.
#define CSR_MTVEC    0x305
#define CSR_MSCRATCH 0x340
#define CSR_MEPC     0x341

#if !defined(__ASSEMBLER__)

#include <stdint.h>
#if defined(__CHERI_PURE_CAPABILITY__)
#include <cheriintrin.h>
#endif /* defined(__CHERI_PURE_CAPABILITY__) */

/* saved state of the general-purpose (capability) registers when the trap took place */
struct [[gnu::aligned(16)]] trap_registers {
    /* capabilities registers on CHERI, otherwise integer registers */
    uintptr_t x[32];
};

/* additional trap information - program counter, trap cause, and trap value */
struct [[gnu::aligned(16)]] trap_context {
    /* capability register on CHERI, otherwise integer register */
    uintptr_t epc;
    /* always integer registers */
    unsigned long cause;
    unsigned long tval;
    /* Reserved for hypervisor trap information; zero on Mocha (RVH disabled). */
    unsigned long tval2;
};

#endif /* !defined(__ASSEMBLER__) */

#if defined(__CHERI_PURE_CAPABILITY__)
#define TRAP_CONTEXT_EPC_OFFSET   0
#define TRAP_CONTEXT_CAUSE_OFFSET 16
#define TRAP_CONTEXT_TVAL_OFFSET  24
#define TRAP_CONTEXT_TVAL2_OFFSET 32
#define TRAP_CONTEXT_SIZE         48
#else /* !defined(__CHERI_PURE_CAPABILITY__) */
#define TRAP_CONTEXT_EPC_OFFSET   0
#define TRAP_CONTEXT_CAUSE_OFFSET 8
#define TRAP_CONTEXT_TVAL_OFFSET  16
#define TRAP_CONTEXT_TVAL2_OFFSET 24
#define TRAP_CONTEXT_SIZE         32
#endif /* !defined(__CHERI_PURE_CAPABILITY__) */

#if !defined(__ASSEMBLER__)

#if defined(__CHERI_PURE_CAPABILITY__)
_Static_assert(sizeof(uintptr_t) == 2 * sizeof(unsigned long), "uintptr_t is not capability size");
#else /* !defined(__CHERI_PURE_CAPABILITY__) */
_Static_assert(sizeof(uintptr_t) == sizeof(unsigned long), "uintptr_t is not register size");
#endif /* !defined(__CHERI_PURE_CAPABILITY__) */
_Static_assert(__builtin_offsetof(struct trap_context, epc) == TRAP_CONTEXT_EPC_OFFSET,
               "incorrect struct trap_context epc offset");
_Static_assert(__builtin_offsetof(struct trap_context, cause) == TRAP_CONTEXT_CAUSE_OFFSET,
               "incorrect struct trap_context cause offset");
_Static_assert(__builtin_offsetof(struct trap_context, tval) == TRAP_CONTEXT_TVAL_OFFSET,
               "incorrect struct trap_context tval offset");
_Static_assert(__builtin_offsetof(struct trap_context, tval2) == TRAP_CONTEXT_TVAL2_OFFSET,
               "incorrect struct trap_context tval2 offset");
_Static_assert(sizeof(struct trap_context) == TRAP_CONTEXT_SIZE,
               "incorrect struct trap_context size");

#endif /* !defined(__ASSEMBLER__) */
