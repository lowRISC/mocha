/* Copyright lowRISC contributors (COSMIC project). */
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
#if defined(__riscv_zcherihybrid)
    .chericap 0 /* we use this as a known-good stack capability to derive permissions from */
    .chericap 0 /* temporary capability storage */
    .chericap 0 /* temporary capability storage */
#else /* !defined(__riscv_zcherihybrid) */
    .dword 0, 0 /* temporary register storage */
.size _scratch, . - _scratch
#endif /* defined(__riscv_zcherihybrid) */

.section .text

.global _trap_vector
.align 4
.type _trap_vector, @function
_trap_vector:
#if defined(__riscv_zcherihybrid)
    /* swap ca0 with scratchpad capability */
    csrrw ca0, mscratchc, ca0
    /* save two more registers to scratchpad area */
    sc csp, SCRATCHPAD_SAVED_SP_OFFSET(ca0)
    sc ca1, SCRATCHPAD_SAVED_A1_OFFSET(ca0)
    /* bump down stack pointer address to next multiple of capability alignment */
    li a1, 0xf
    not a1, a1
    and sp, sp, a1
    /* load known-good capability to use for our stack */
    lc ca1, SCRATCHPAD_TRAP_STACK_OFFSET(ca0)
    /* recreate a valid stack capability */
    scaddr csp, ca1, sp
    /* now we have a valid stack, allocate struct trap_registers and save registers to it */
    add csp, csp, -512
    sc cnull, 0(csp)
    sc cra,   16(csp)
    /* csp is in scratchpad, do not store yet */
    sc cgp,   48(csp)
    sc ctp,   64(csp)
    sc ct0,   80(csp)
    sc ct1,   96(csp)
    sc ct2,   112(csp)
    sc cs0,   128(csp)
    sc cs1,   144(csp)
    /* ca0 is in mscratchc, do not store yet */
    /* ca1 is in scratchpad, do not store yet */
    sc ca2,   192(csp)
    sc ca3,   208(csp)
    sc ca4,   224(csp)
    sc ca5,   240(csp)
    sc ca6,   256(csp)
    sc ca7,   272(csp)
    sc cs2,   288(csp)
    sc cs3,   304(csp)
    sc cs4,   320(csp)
    sc cs5,   336(csp)
    sc cs6,   352(csp)
    sc cs7,   368(csp)
    sc cs8,   384(csp)
    sc cs9,   400(csp)
    sc cs10,  416(csp)
    sc cs11,  432(csp)
    sc ct3,   448(csp)
    sc ct4,   464(csp)
    sc ct5,   480(csp)
    sc ct6,   496(csp)
    /* reload csp, ca1 from scratchpad */
    lc ct0, SCRATCHPAD_SAVED_SP_OFFSET(ca0)
    sc ct0, 32(csp)
    lc ct1, SCRATCHPAD_SAVED_A1_OFFSET(ca0)
    sc ct1, 176(csp)
    /* swap back ca0 with scratchpad capability */
    csrrw ca0, mscratchc, ca0
    sc ca0, 160(csp)
    /* set capability in first argument register */
    li a0, 512
    scbnds ca0, csp, a0
#else /* !defined(__riscv_zcherihybrid) */
    /* swap a0 with scratchpad pointer */
    csrrw a0, mscratch, a0
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
    csrrw a0, mscratch, a0
    sd a0, 80(sp)
    /* set pointer in first argument register */
    mv a0, sp
#endif /* defined(__riscv_zcherihybrid) */

#if defined(__riscv_zcherihybrid)
    /* allocate struct trap_context and save registers to it */
    add csp, csp, -TRAP_CONTEXT_SIZE
    csrr ct0, mepcc
    sc ct0, TRAP_CONTEXT_EPC_OFFSET(csp)
    csrr t0, mcause
    sd t0, TRAP_CONTEXT_CAUSE_OFFSET(csp)
    csrr t0, mtval
    sd t0, TRAP_CONTEXT_TVAL_OFFSET(csp)
    csrr t0, mtval2
    sd t0, TRAP_CONTEXT_TVAL2_OFFSET(csp)
    /* set capability in second argument register */
    li a1, TRAP_CONTEXT_SIZE
    scbnds ca1, csp, a1
#else /* !defined(__riscv_zcherihybrid) */
    /* allocate struct trap_context and save registers to it */
    add sp, sp, -TRAP_CONTEXT_SIZE
    csrr t0, mepc
    sd t0, TRAP_CONTEXT_EPC_OFFSET(sp)
    csrr t0, mcause
    sd t0, TRAP_CONTEXT_CAUSE_OFFSET(sp)
    csrr t0, mtval
    sd t0, TRAP_CONTEXT_TVAL_OFFSET(sp)
    csrr t0, mtval2
    sd t0, TRAP_CONTEXT_TVAL2_OFFSET(sp)
    /* set pointer in second argument register */
    mv a1, sp
#endif /* defined(__riscv_zcherihybrid) */

    /* call into trap handler in C */
    call _trap_handler

#if defined(__riscv_zcherihybrid)
    /* load in new mepcc */
    lc ct0, TRAP_CONTEXT_EPC_OFFSET(csp)
    csrw mepcc, ct0
    /* deallocate */
    add csp, csp, TRAP_CONTEXT_SIZE
#else /* !defined(__riscv_zcherihybrid) */
    /* load in new mepc */
    ld t0, TRAP_CONTEXT_EPC_OFFSET(sp)
    csrw mepc, t0
    /* deallocate */
    add sp, sp, TRAP_CONTEXT_SIZE
#endif /* defined(__riscv_zcherihybrid) */

#if defined(__riscv_zcherihybrid)
    /* reload regs */
    lc cnull, 0(csp)
    lc cra,   16(csp)
    /* we are still using stack, do not load csp yet */
    lc cgp,   48(csp)
    lc ctp,   64(csp)
    lc ct0,   80(csp)
    lc ct1,   96(csp)
    lc ct2,   112(csp)
    lc cs0,   128(csp)
    lc cs1,   144(csp)
    lc ca0,   160(csp)
    lc ca1,   176(csp)
    lc ca2,   192(csp)
    lc ca3,   208(csp)
    lc ca4,   224(csp)
    lc ca5,   240(csp)
    lc ca6,   256(csp)
    lc ca7,   272(csp)
    lc cs2,   288(csp)
    lc cs3,   304(csp)
    lc cs4,   320(csp)
    lc cs5,   336(csp)
    lc cs6,   352(csp)
    lc cs7,   368(csp)
    lc cs8,   384(csp)
    lc cs9,   400(csp)
    lc cs10,  416(csp)
    lc cs11,  432(csp)
    lc ct3,   448(csp)
    lc ct4,   464(csp)
    lc ct5,   480(csp)
    lc ct6,   496(csp)
    /* done with stack, restore csp */
    lc csp, 32(csp)
#else /* !defined(__riscv_zcherihybrid) */
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
#endif /* defined(__riscv_zcherihybrid) */
    mret
.size _trap_vector, . - _trap_vector
