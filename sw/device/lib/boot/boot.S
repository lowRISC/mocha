/* Copyright lowRISC and contributors (COSMIC project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#include "boot/scratchpad.h"
#include "boot/trap.h"

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

#if defined(__CHERI_PURE_CAPABILITY__)
    /* The ROM enters in integer mode, so purecap startup requires Zyhybrid. */
#if !defined(__riscv_zyhybrid)
#error "Purecap startup from the integer boot ROM requires Zyhybrid"
#endif
    /* switch to capability mode */
    ymodeswy

    /* initialise a0 as the infinite capability */
    auipc a0, 0
    yaddrw a0, a0, zero
    ymodew a0, a0, zero
    /* store it for use by C code */
    lly a1, _infinite_cap
    yaddrw a1, a0, a1
    sy a0, 0(a1)
    ymv a1, zero

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
    /* t0 holds the pointer to the current capability relocation entry */
    lly t0, __start___cap_relocs
    lly t1, __stop___cap_relocs
    sub t2, t1, t0
    yaddrw t0, a0, t0
    ybndsrw t0, t0, t2
cap_relocs_loop:
    beq t0, t1, cap_relocs_end

    ld t2, 0(t0)  /* t2 = cr_location */
    ld t3, 8(t0)  /* t3 = cr_base */
    ld t4, 16(t0) /* t4 = cr_offset */
    ld t5, 24(t0) /* t5 = cr_length */
    ld t6, 32(t0) /* t6 = cr_flags */

    /* create the capability from the infinite capability,
     * setting the base address and offset */
    yaddrw s0, a0, t3
    yadd s0, s0, t4
    /* set capability mode to capability pointer mode */
    ymodew s0, s0, zero

    /* YPERMC clears the selected permissions (unlike the old ACPERM mask).
     * Restrict capability permissions based on the flags field. */
    /* t3 is reused to test each flag */
    li t3, (1 << 63) /* executable capability if set, otherwise data capability */
    and t3, t3, t6
    bnez t3, cap_reloc_executable

    /* data capability, exclude execute permissions */
    li t3, __CHERI_CAP_PERMISSION_EXECUTE__
    ypermc s0, s0, t3
    li t3, (1 << 62) /* if data capability, next bit determines whether it is read-only */
    and t3, t3, t6
    bnez t3, cap_reloc_data_ro
    /* read-write data capability */
    j cap_reloc_data

cap_reloc_executable:
    /* remove write permissions and do not set bounds for executable capabilities */
    li t3, __CHERI_CAP_PERMISSION_WRITE__
    ypermc s0, s0, t3
    j cap_reloc_write_cap

cap_reloc_data_ro:
    /* remove write permissions for read-only data capabilities */
    li t3, __CHERI_CAP_PERMISSION_WRITE__
    ypermc s0, s0, t3
    /* fallthrough */

cap_reloc_data:
    /* set bounds for all data capabilities */
    ybndsrw s0, s0, t5
    /* fallthrough */

cap_reloc_write_cap:
    /* write created capability to the corresponding location */
    yaddrw s1, a0, t2
    sy s0, 0(s1)

    /* next relocation entry */
    yadd t0, t0, 40
    j cap_relocs_loop
cap_relocs_end:
    /* clear used registers */
    ymv t0, zero
    ymv t1, zero
    ymv s0, zero
    ymv s1, zero
    ymv t2, zero
    ymv t3, zero
    ymv t4, zero
    ymv t5, zero
    ymv t6, zero
#endif /* defined(__CHERI_PURE_CAPABILITY__) */

    /* zero out bss */
#if defined(__CHERI_PURE_CAPABILITY__)
cheri_zero_bss:
    lly t0, _bss_start
    lly t1, _bss_end
    sub t2, t1, t0
    yaddrw t0, a0, t0
    ybndsrw t0, t0, t2
cheri_zero_bss_loop:
    beq t0, t1, cheri_zero_bss_end
    sd zero, 0(t0)
    yadd t0, t0, 8
    j cheri_zero_bss_loop
cheri_zero_bss_end:
    /* clear used registers */
    ymv t0, zero
    ymv t1, zero
    ymv t2, zero
#else /* !defined(__CHERI_PURE_CAPABILITY__) */
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
#endif /* defined(__CHERI_PURE_CAPABILITY__) */

#if defined(__CHERI_PURE_CAPABILITY__)
    /* derive a stack pointer from the infinite capability */
    /* limit stack size */
    lly sp, _stack_bottom
    lgy t0, _stack_len
    yaddrw sp, a0, sp
    ybndsw sp, sp, t0
    /* stack grows downwards, so adjust address to top */
    yadd sp, sp, t0
    /* disable execute permissions on the stack */
    li t0, __CHERI_CAP_PERMISSION_EXECUTE__
    ypermc sp, sp, t0
    ymv t0, zero
#else /* !defined(__CHERI_PURE_CAPABILITY__) */
    /* in non-CHERI mode, just load the stack top */
    la sp, _stack_top
#endif /* defined(__CHERI_PURE_CAPABILITY__) */

setup_trap_vector:
#if defined(__CHERI_PURE_CAPABILITY__)
    /* create a trap handler capability and install it in mtvec */
    lly t0, _trap_vector
    yaddrw t0, a0, t0
    csrw CSR_MTVEC, t0
    ymv t0, zero
#else /* !defined(__CHERI_PURE_CAPABILITY__) */
    /* install a new trap handler */
    la t0, _trap_vector
    csrw CSR_MTVEC, t0
    mv t0, zero
#endif /* defined(__CHERI_PURE_CAPABILITY__) */

#if defined(__CHERI_PURE_CAPABILITY__)
setup_scratchpad:
    /* create capability for scratchpad area in a1 */
    lly t0, _scratch
    li t1, SCRATCHPAD_SIZE
    yaddrw t0, a0, t0
    ybndsw a1, t0, t1

    /* set up a known-good stack capability in the scratchpad area */
    lly t0, _stack_bottom
    lgy t1, _stack_len
    yaddrw t0, a0, t0
    ybndsw t0, t0, t1
    yadd t0, t0, t1
    li t1, __CHERI_CAP_PERMISSION_EXECUTE__
    ypermc t0, t0, t1
    sy t0, SCRATCHPAD_TRAP_STACK_OFFSET(a1)
    /* mscratch will contain this scratchpad area */
    csrw CSR_MSCRATCH, a1
    ymv t0, zero
    ymv a1, zero
    mv t1, zero
#else /* !defined(__CHERI_PURE_CAPABILITY__) */
    la t0, _scratch
    csrw CSR_MSCRATCH, t0
    mv t0, zero
#endif /* defined(__CHERI_PURE_CAPABILITY__) */

#if defined(__CHERI_PURE_CAPABILITY__)
    /* destroy infinite capability, we have already stored it away */
    ymv a0, zero
#endif /* defined(__CHERI_PURE_CAPABILITY__) */

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

#if defined(__CHERI_PURE_CAPABILITY__)
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
#endif /* defined(__CHERI_PURE_CAPABILITY__) */
