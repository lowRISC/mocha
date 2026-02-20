// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Nicole Narr <narrn@ethz.ch>
// - Christopher Reinwardt <creinwar@ethz.ch>
// Date:   19.11.2022

#ifndef AXI_LLC_REG32_C_
#define AXI_LLC_REG32_C_

#include "axi_llc_reg32.h"

static inline void set_reg_64(unsigned long int value, void *base, unsigned int low_off, unsigned int high_off)
{
    iowrite32(value, (volatile unsigned int *) (base + low_off));
    iowrite32((value >> 32), (volatile unsigned int *) (base + high_off));
}

static inline unsigned long int get_reg_64(void *base, unsigned int low_off, unsigned int high_off)
{
    unsigned long int tmp = 0;
    tmp = ioread32((volatile unsigned int *) (base + high_off));
    tmp <<= 32;
    tmp |= ioread32((volatile unsigned int *) (base + low_off));
    return tmp;
}

static inline void set_reg_32(unsigned int value, void *base, unsigned int off)
{
    iowrite32(value, (volatile unsigned int *) (base + off));
}

static inline unsigned int get_reg_32(void *base, unsigned int off)
{
    return ioread32((volatile unsigned int *) (base + off));
}

// Software configurable registers
void axi_llc_reg32_set_spm(unsigned long int value, void *base)
{
    set_reg_64(value, base, AXI_LLC_CFG_SPM_LOW_REG_OFFSET, AXI_LLC_CFG_SPM_HIGH_REG_OFFSET);
    set_reg_32(0x1, base, AXI_LLC_COMMIT_CFG_REG_OFFSET);
}

void axi_llc_reg32_set_flush(unsigned long int value, void *base)
{
    set_reg_64(value, base, AXI_LLC_CFG_FLUSH_LOW_REG_OFFSET, AXI_LLC_CFG_FLUSH_HIGH_REG_OFFSET);
    set_reg_32(0x1, base, AXI_LLC_COMMIT_CFG_REG_OFFSET);
}

unsigned long int axi_llc_reg32_get_spm(void *base)
{
    return get_reg_64(base, AXI_LLC_CFG_SPM_LOW_REG_OFFSET, AXI_LLC_CFG_SPM_HIGH_REG_OFFSET);
}

unsigned long int axi_llc_reg32_get_flush(void *base)
{
    return get_reg_64(base, AXI_LLC_CFG_FLUSH_LOW_REG_OFFSET, AXI_LLC_CFG_FLUSH_HIGH_REG_OFFSET);
}


// Information registers
unsigned long int axi_llc_reg32_get_flushed(void *base)
{
    return get_reg_64(base, AXI_LLC_FLUSHED_LOW_REG_OFFSET, AXI_LLC_FLUSHED_HIGH_REG_OFFSET);
}

unsigned long int axi_llc_reg32_get_bist_out(void *base)
{
    return get_reg_64(base, AXI_LLC_BIST_OUT_LOW_REG_OFFSET, AXI_LLC_BIST_OUT_HIGH_REG_OFFSET);
}

unsigned long int axi_llc_reg32_get_set_asso(void *base)
{
    return get_reg_64(base, AXI_LLC_SET_ASSO_LOW_REG_OFFSET, AXI_LLC_SET_ASSO_HIGH_REG_OFFSET);
}

unsigned long int axi_llc_reg32_get_num_lines(void *base)
{
    return get_reg_64(base, AXI_LLC_NUM_LINES_LOW_REG_OFFSET, AXI_LLC_NUM_LINES_HIGH_REG_OFFSET);
}

unsigned long int axi_llc_reg32_get_num_blocks(void *base)
{
    return get_reg_64(base, AXI_LLC_NUM_BLOCKS_LOW_REG_OFFSET, AXI_LLC_NUM_BLOCKS_HIGH_REG_OFFSET);
}

unsigned long int axi_llc_reg32_get_version(void *base)
{
    return get_reg_64(base, AXI_LLC_VERSION_LOW_REG_OFFSET, AXI_LLC_VERSION_HIGH_REG_OFFSET);
}


// Utility functions
void axi_llc_reg32_all_cache(void *base)
{
    axi_llc_reg32_set_spm(0x0, base);
}

void axi_llc_reg32_all_spm(void *base)
{
    // Superfluous bits will be reset to 0 by software anyways
    axi_llc_reg32_set_spm((unsigned long int) -1, base);
}

void axi_llc_reg32_flush_all(void *base)
{
    axi_llc_reg32_set_flush((unsigned long int) -1, base);
}


#endif
