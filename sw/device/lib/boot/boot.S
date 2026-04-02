/* Copyright lowRISC contributors (COSMIC project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#include "boot/scratchpad.h"

.section .text

.global _start
_start:
    /* reset registers */
    mv ra, zero
    mv sp, zero
    mv gp, zero
    mv tp, zero
    mv t0, zero
    mv t1, zero
    mv t2, zero
    mv s0, zero
    mv s1, zero
    mv a0, zero
    mv a1, zero
    mv a2, zero
    mv a3, zero
    mv a4, zero
    mv a5, zero
    mv a6, zero
    mv a7, zero
    mv s2, zero
    mv s3, zero
    mv s4, zero
    mv s5, zero
    mv s6, zero
    mv s7, zero
    mv s8, zero
    mv s9, zero
    mv s10, zero
    mv s11, zero
    mv t3, zero
    mv t4, zero
    mv t5, zero
    mv t6, zero

#if defined(__riscv_zcherihybrid)
    /* enable CHERI instructions */
    csrs mseccfg, (1 << 3) /* mseccfg.CRE */
    /* switch to capability mode */
    modesw.cap

    /* initialise ca0 as the infinite capability */
    auipc ca0, 0
    scaddr ca0, ca0, zero
    scmode ca0, ca0, zero
    /* store it for use by C code */
    llc ca1, _infinite_cap
    scaddr ca1, ca0, a1
    sc ca0, 0(ca1)
    mv ca1, cnull

    /* perform capability relocation.
     * the system memory starts with all tag bits unset, therefore we must
     * iterate over any capabilities that need to be initialised
     * (global capabilities, function pointers, etc) and initialise them
     * using our root capability before we are able to run C code.
     * this information is stored in the __cap_relocs section which consists
     * of an array of "capability relocations" (cap_reloc).
     * the structure in memory is:
     * typedef struct {
     *     unsigned long cr_location;
     *     unsigned long cr_base;
     *     unsigned long cr_offset;
     *     unsigned long cr_length;
     *     unsigned long cr_flags;
     * } cap_reloc;
     * see the CHERI-RISC-V ELF psABI for more information.
     */
cap_relocs:
    /* ct0 holds the pointer to the current capability relocation entry */
    llc ct0, __start___cap_relocs
    llc ct1, __stop___cap_relocs
    sub t2, t1, t0
    scaddr ct0, ca0, t0
    scbndsr ct0, ct0, t2
cap_relocs_loop:
    beq t0, t1, cap_relocs_end

    ld t2, 0(ct0)  /* t2 = cr_location */
    ld t3, 8(ct0)  /* t3 = cr_base */
    ld t4, 16(ct0) /* t4 = cr_offset */
    ld t5, 24(ct0) /* t5 = cr_length */
    ld t6, 32(ct0) /* t6 = cr_flags */

    /* create the capability from the infinite capability,
     * setting the base address and offset */
    scaddr cs0, ca0, t3
    add cs0, cs0, t4
    /* set capability mode to capability pointer mode */
    scmode cs0, cs0, zero

    /* restrict capability permissions based on the flags field */
    /* t3 is reused to test each flag */
    li t3, (1 << 63) /* executable capability if set, otherwise data capability */
    and t3, t3, t6
    bnez t3, cap_reloc_executable

    /* data capability, exclude execute permissions */
    li t3, ~(__CHERI_CAP_PERMISSION_EXECUTE__)
    acperm cs0, cs0, t3
    li t3, (1 << 62) /* if data capability, next bit determines whether it is read-only */
    and t3, t3, t6
    bnez t3, cap_reloc_data_ro
    /* read-write data capability */
    j cap_reloc_data

cap_reloc_executable:
    /* remove write permissions and do not set bounds for executable capabilities */
    li t3, ~(__CHERI_CAP_PERMISSION_WRITE__)
    acperm cs0, cs0, t3
    j cap_reloc_write_cap

cap_reloc_data_ro:
    /* remove write permissions for read-only data capabilities */
    li t3, ~(__CHERI_CAP_PERMISSION_WRITE__)
    acperm cs0, cs0, t3
    /* fallthrough */

cap_reloc_data:
    /* set bounds for all data capabilities */
    scbndsr cs0, cs0, t5
    /* fallthrough */

cap_reloc_write_cap:
    /* write created capability to the corresponding location */
    scaddr cs1, ca0, t2
    sc cs0, 0(cs1)

    /* next relocation entry */
    add ct0, ct0, 40
    j cap_relocs_loop
cap_relocs_end:
    /* clear used registers */
    mv ct0, cnull
    mv ct1, cnull
    mv cs0, cnull
    mv cs1, cnull
    mv ct2, cnull
    mv ct3, cnull
    mv ct4, cnull
    mv ct5, cnull
    mv ct6, cnull
#endif /* defined(__riscv_zcherihybrid) */

    /* zero out bss */
#if defined(__riscv_zcherihybrid)
cheri_zero_bss:
    llc ct0, _bss_start
    llc ct1, _bss_end
    sub t2, t1, t0
    scaddr ct0, ca0, t0
    scbndsr ct0, ct0, t2
cheri_zero_bss_loop:
    beq t0, t1, cheri_zero_bss_end
    sd zero, 0(ct0)
    add ct0, ct0, 8
    j cheri_zero_bss_loop
cheri_zero_bss_end:
    /* clear used registers */
    mv ct0, cnull
    mv ct1, cnull
    mv ct2, cnull
#else /* !defined(__riscv_zcherihybrid) */
zero_bss:
    la t0, _bss_start
    la t1, _bss_end
zero_bss_loop:
    beq t0, t1, zero_bss_end
    sd zero, 0(t0)
    add t0, t0, 8
    j zero_bss_loop
zero_bss_end:
    /* clear used registers */
    mv t0, zero
    mv t1, zero
#endif /* defined(__riscv_zcherihybrid) */

#if defined(__riscv_zcherihybrid)
    /* derive a stack pointer from the infinite capability */
    /* limit stack size */
    llc csp, _stack_bottom
    lgc ct0, _stack_len
    scaddr csp, ca0, sp
    scbnds csp, csp, t0
    /* stack grows downwards, so adjust address to top */
    add csp, csp, t0
    /* disable execute permissions on the stack */
    li t0, ~(__CHERI_CAP_PERMISSION_EXECUTE__)
    acperm csp, csp, t0
    mv ct0, cnull
#else /* !defined(__riscv_zcherihybrid) */
    /* in non-CHERI mode, just load the stack top */
    la sp, _stack_top
#endif /* defined(__riscv_zcherihybrid) */

setup_trap_vector:
#if defined(__riscv_zcherihybrid)
    /* create a trap handler capability and install it in mtvecc */
    llc ct0, _trap_vector
    scaddr ct0, ca0, t0
    csrw mtvecc, ct0
    mv ct0, cnull
#else /* !defined(__riscv_zcherihybrid) */
    /* install a new trap handler */
    la t0, _trap_vector
    csrw mtvec, t0
    mv t0, zero
#endif /* defined(__riscv_zcherihybrid) */

#if defined(__riscv_zcherihybrid)
setup_scratchpad:
    /* create capability for scratchpad area in ca1 */
    llc ct0, _scratch
    li t1, SCRATCHPAD_SIZE
    scaddr ct0, ca0, t0
    scbnds ca1, ct0, t1

    /* set up a known-good stack capability in the scratchpad area */
    llc ct0, _stack_bottom
    lgc ct1, _stack_len
    scaddr ct0, ca0, t0
    scbnds ct0, ct0, t1
    add ct0, ct0, t1
    li t1, ~(__CHERI_CAP_PERMISSION_EXECUTE__)
    acperm ct0, ct0, t1
    sc ct0, SCRATCHPAD_TRAP_STACK_OFFSET(ca1)
    /* mscratch will contain this scratchpad area */
    csrw mscratchc, ca1
    mv ct0, cnull
    mv ca1, cnull
    mv t1, zero
#else /* !defined(__riscv_zcherihybrid) */
    la t0, _scratch
    csrw mscratch, t0
    mv t0, zero
#endif /* defined(__riscv_zcherihybrid) */

#if defined(__riscv_zcherihybrid)
    /* destroy infinite capability, we have already stored it away */
    mv ca0, cnull
#endif /* defined(__riscv_zcherihybrid) */

    /* jump into main */
    jal main

    beqz a0, success
    j failure
success:
    wfi
    j success
failure:
    wfi
    j failure

#if defined(__riscv_zcherihybrid)
/* storage for the infinite capability for use by C code. */
.section .data
.align 4
.global _infinite_cap
.type _infinite_cap, @object
_infinite_cap:
    .chericap 0
/* the size must be provided, otherwise the linker will not know how to
 * generate a cap_reloc entry for it. */
.size _infinite_cap, . - _infinite_cap
#endif /* defined(__riscv_zcherihybrid) */
