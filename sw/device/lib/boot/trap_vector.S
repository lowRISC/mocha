/* Copyright lowRISC and contributors (COSMIC project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/* assembly trap vector routine.
 * direct users of this code (e.g the test framework)
 * should provide the following function in C:
 * void _trap_handler(struct trap_registers *, struct trap_context *) */

#include "boot/scratchpad.h"
#include "boot/trap.h"

.section .data
/* scratchpad area stored in mscratch capability, see scratchpad.h */
.global _scratch
.align 4 /* capability alignment */
.type _scratch, @object
_scratch:
#if defined(__CHERI_PURE_CAPABILITY__)
    .chericap 0 /* we use this as a known-good stack capability to derive permissions from */
    .chericap 0 /* temporary capability storage */
    .chericap 0 /* temporary capability storage */
#else /* !defined(__CHERI_PURE_CAPABILITY__) */
    .dword 0, 0 /* temporary register storage */
#endif /* defined(__CHERI_PURE_CAPABILITY__) */
.size _scratch, . - _scratch

.section .text

.global _trap_vector
.align 4
.type _trap_vector, @function
_trap_vector:
#if defined(__CHERI_PURE_CAPABILITY__)
    /* swap a0 with scratchpad capability */
    csrrw a0, CSR_MSCRATCH, a0
    /* save two more registers to scratchpad area */
    sy sp, SCRATCHPAD_SAVED_SP_OFFSET(a0)
    sy a1, SCRATCHPAD_SAVED_A1_OFFSET(a0)
    /* bump down stack pointer address to next multiple of capability alignment */
    li a1, 0xf
    not a1, a1
    and sp, sp, a1
    /* load known-good capability to use for our stack */
    ly a1, SCRATCHPAD_TRAP_STACK_OFFSET(a0)
    /* recreate a valid stack capability */
    yaddrw sp, a1, sp
    /* now we have a valid stack, allocate struct trap_registers and save registers to it */
    yadd sp, sp, -512
    sy zero, 0(sp)
    sy ra,   16(sp)
    /* sp is in scratchpad, do not store yet */
    sy gp,   48(sp)
    sy tp,   64(sp)
    sy t0,   80(sp)
    sy t1,   96(sp)
    sy t2,   112(sp)
    sy s0,   128(sp)
    sy s1,   144(sp)
    /* a0 is in mscratch, do not store yet */
    /* a1 is in scratchpad, do not store yet */
    sy a2,   192(sp)
    sy a3,   208(sp)
    sy a4,   224(sp)
    sy a5,   240(sp)
    sy a6,   256(sp)
    sy a7,   272(sp)
    sy s2,   288(sp)
    sy s3,   304(sp)
    sy s4,   320(sp)
    sy s5,   336(sp)
    sy s6,   352(sp)
    sy s7,   368(sp)
    sy s8,   384(sp)
    sy s9,   400(sp)
    sy s10,  416(sp)
    sy s11,  432(sp)
    sy t3,   448(sp)
    sy t4,   464(sp)
    sy t5,   480(sp)
    sy t6,   496(sp)
    /* reload sp, a1 from scratchpad */
    ly t0, SCRATCHPAD_SAVED_SP_OFFSET(a0)
    sy t0, 32(sp)
    ly t1, SCRATCHPAD_SAVED_A1_OFFSET(a0)
    sy t1, 176(sp)
    /* swap back a0 with scratchpad capability */
    csrrw a0, CSR_MSCRATCH, a0
    sy a0, 160(sp)
    /* set capability in first argument register */
    li a0, 512
    ybndsw a0, sp, a0
#else /* !defined(__CHERI_PURE_CAPABILITY__) */
    /* swap a0 with scratchpad pointer */
    csrrw a0, CSR_MSCRATCH, a0
    /* save two more registers to scratchpad area */
    sd sp, SCRATCHPAD_SAVED_SP_OFFSET(a0)
    sd a1, SCRATCHPAD_SAVED_A1_OFFSET(a0)
    /* bump down stack pointer address to next multiple of capability alignment */
    li a1, 0xf
    not a1, a1
    and sp, sp, a1
    /* allocate struct trap_registers and save registers to it */
    add sp, sp, -256
    sd zero, 0(sp)
    sd ra,   8(sp)
    /* sp is in scratchpad, do not store yet */
    sd gp,   24(sp)
    sd tp,   32(sp)
    sd t0,   40(sp)
    sd t1,   48(sp)
    sd t2,   56(sp)
    sd s0,   64(sp)
    sd s1,   72(sp)
    /* a0 is in mscratch, do not store yet */
    /* a1 is in scratchpad, do not store yet */
    sd a2,   96(sp)
    sd a3,   104(sp)
    sd a4,   112(sp)
    sd a5,   120(sp)
    sd a6,   128(sp)
    sd a7,   136(sp)
    sd s2,   144(sp)
    sd s3,   152(sp)
    sd s4,   160(sp)
    sd s5,   168(sp)
    sd s6,   176(sp)
    sd s7,   184(sp)
    sd s8,   192(sp)
    sd s9,   200(sp)
    sd s10,  208(sp)
    sd s11,  216(sp)
    sd t3,   224(sp)
    sd t4,   232(sp)
    sd t5,   240(sp)
    sd t6,   248(sp)
    /* reload sp, a1 from scratchpad */
    ld t0, SCRATCHPAD_SAVED_SP_OFFSET(a0)
    sd t0, 16(sp)
    ld t0, SCRATCHPAD_SAVED_A1_OFFSET(a0)
    sd t0, 88(sp)
    /* swap back a0 with scratchpad pointer */
    csrrw a0, CSR_MSCRATCH, a0
    sd a0, 80(sp)
    /* set pointer in first argument register */
    mv a0, sp
#endif /* defined(__CHERI_PURE_CAPABILITY__) */

#if defined(__CHERI_PURE_CAPABILITY__)
    /* allocate struct trap_context and save registers to it */
    yadd sp, sp, -TRAP_CONTEXT_SIZE
    csrr t0, CSR_MEPC
    sy t0, TRAP_CONTEXT_EPC_OFFSET(sp)
    csrr t0, mcause
    sd t0, TRAP_CONTEXT_CAUSE_OFFSET(sp)
    csrr t0, mtval
    sd t0, TRAP_CONTEXT_TVAL_OFFSET(sp)
    /* Mocha has no H extension, so mtval2 is unavailable. */
    li t0, 0
    sd t0, TRAP_CONTEXT_TVAL2_OFFSET(sp)
    /* set capability in second argument register */
    li a1, TRAP_CONTEXT_SIZE
    ybndsw a1, sp, a1
#else /* !defined(__CHERI_PURE_CAPABILITY__) */
    /* allocate struct trap_context and save registers to it */
    add sp, sp, -TRAP_CONTEXT_SIZE
    csrr t0, CSR_MEPC
    sd t0, TRAP_CONTEXT_EPC_OFFSET(sp)
    csrr t0, mcause
    sd t0, TRAP_CONTEXT_CAUSE_OFFSET(sp)
    csrr t0, mtval
    sd t0, TRAP_CONTEXT_TVAL_OFFSET(sp)
    /* Mocha has no H extension, so mtval2 is unavailable. */
    li t0, 0
    sd t0, TRAP_CONTEXT_TVAL2_OFFSET(sp)
    /* set pointer in second argument register */
    mv a1, sp
#endif /* defined(__CHERI_PURE_CAPABILITY__) */

    /* call into trap handler in C */
    call _trap_handler

#if defined(__CHERI_PURE_CAPABILITY__)
    /* load in new mepc */
    ly t0, TRAP_CONTEXT_EPC_OFFSET(sp)
    csrw CSR_MEPC, t0
    /* deallocate */
    yadd sp, sp, TRAP_CONTEXT_SIZE
#else /* !defined(__CHERI_PURE_CAPABILITY__) */
    /* load in new mepc */
    ld t0, TRAP_CONTEXT_EPC_OFFSET(sp)
    csrw CSR_MEPC, t0
    /* deallocate */
    add sp, sp, TRAP_CONTEXT_SIZE
#endif /* defined(__CHERI_PURE_CAPABILITY__) */

#if defined(__CHERI_PURE_CAPABILITY__)
    /* reload regs */
    ly zero, 0(sp)
    ly ra,   16(sp)
    /* we are still using stack, do not load sp yet */
    ly gp,   48(sp)
    ly tp,   64(sp)
    ly t0,   80(sp)
    ly t1,   96(sp)
    ly t2,   112(sp)
    ly s0,   128(sp)
    ly s1,   144(sp)
    ly a0,   160(sp)
    ly a1,   176(sp)
    ly a2,   192(sp)
    ly a3,   208(sp)
    ly a4,   224(sp)
    ly a5,   240(sp)
    ly a6,   256(sp)
    ly a7,   272(sp)
    ly s2,   288(sp)
    ly s3,   304(sp)
    ly s4,   320(sp)
    ly s5,   336(sp)
    ly s6,   352(sp)
    ly s7,   368(sp)
    ly s8,   384(sp)
    ly s9,   400(sp)
    ly s10,  416(sp)
    ly s11,  432(sp)
    ly t3,   448(sp)
    ly t4,   464(sp)
    ly t5,   480(sp)
    ly t6,   496(sp)
    /* done with stack, restore sp */
    ly sp, 32(sp)
#else /* !defined(__CHERI_PURE_CAPABILITY__) */
    /* reload regs */
    ld zero, 0(sp)
    ld ra,   8(sp)
    /* we are still using stack, do not load sp yet */
    ld gp,   24(sp)
    ld tp,   32(sp)
    ld t0,   40(sp)
    ld t1,   48(sp)
    ld t2,   56(sp)
    ld s0,   64(sp)
    ld s1,   72(sp)
    ld a0,   80(sp)
    ld a1,   88(sp)
    ld a2,   96(sp)
    ld a3,   104(sp)
    ld a4,   112(sp)
    ld a5,   120(sp)
    ld a6,   128(sp)
    ld a7,   136(sp)
    ld s2,   144(sp)
    ld s3,   152(sp)
    ld s4,   160(sp)
    ld s5,   168(sp)
    ld s6,   176(sp)
    ld s7,   184(sp)
    ld s8,   192(sp)
    ld s9,   200(sp)
    ld s10,  208(sp)
    ld s11,  216(sp)
    ld t3,   224(sp)
    ld t4,   232(sp)
    ld t5,   240(sp)
    ld t6,   248(sp)
    /* done with stack, restore sp */
    ld sp, 16(sp)
#endif /* defined(__CHERI_PURE_CAPABILITY__) */
    mret
.size _trap_vector, . - _trap_vector
