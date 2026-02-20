// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Nicole Narr <narrn@ethz.ch>
// - Christopher Reinwardt <creinwar@ethz.ch>
// Date:   19.11.2022

#ifndef AXI_LLC_REG32_H_
#define AXI_LLC_REG32_H_

// Register offset definitions
#include "axi_llc_regs.h"

// 32-bit write to IO memory region
static inline void __axi_llc_iowrite32(unsigned int value, volatile unsigned int *addr)
{
    *addr = value;
}

// 32-bit read from IO memory region
static inline unsigned int __axi_llc_ioread32(volatile unsigned int *addr)
{
    return *addr;
}

#ifndef iowrite32
#define iowrite32 __axi_llc_iowrite32
#endif

#ifndef ioread32
#define ioread32 __axi_llc_ioread32
#endif

// Software configurable registers
void axi_llc_reg32_set_spm(unsigned long int value, void *base);

void axi_llc_reg32_set_flush(unsigned long int value, void *base);

unsigned long int axi_llc_reg32_get_spm(void *base);

unsigned long int axi_llc_reg32_get_flush(void *base);


// Information registers
unsigned long int axi_llc_reg32_get_flushed(void *base);

unsigned long int axi_llc_reg32_get_bist_out(void *base);

unsigned long int axi_llc_reg32_get_set_asso(void *base);

unsigned long int axi_llc_reg32_get_num_lines(void *base);

unsigned long int axi_llc_reg32_get_num_blocks(void *base);

unsigned long int axi_llc_reg32_get_version(void *base);


// Utility functions
void axi_llc_reg32_all_cache(void *base);

void axi_llc_reg32_all_spm(void *base);

void axi_llc_reg32_flush_all(void *base);



#endif