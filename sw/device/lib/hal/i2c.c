// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/i2c.h"
#include "hal/mmio.h"
#include "hal/mocha.h"
#include <stdbool.h>
#include <stdint.h>

/**
 * Performs a 32-bit integer unsigned division, rounding up. The bottom
 * 16 bits of the result are then returned.
 *
 * As usual, a divisor of 0 is still Undefined Behavior.
 *
 * Adapted from OpenTitan sw/device/lib/dif/dif_i2c.c
 */
static uint16_t rnd_up_div(uint32_t a, uint32_t b)
{
    const uint32_t result = ((a - 1) / b) + 1;
    return (uint16_t)result;
}

void i2c_init(i2c_t i2c)
{
    // -- Set timing parameters --
    //
    // Using Standard-mode (100 kbits/s) constants, taken from the NXP I^2C specification
    // "UM10204" Table 10 (rev. 6) / Table 11 (rev. 7).
    // Faster modes will require different/adjustable constants and checking that SCL high/low
    // cycles calculated are sufficient to still allow the clock stretching logic to function.
    //
    // SCL high cycles calculation adapted from OpenTitan sw/device/lib/dif/dif_i2c.c
    uint32_t rise_cycles = rnd_up_div(I2C_RISE_NS, SYSCLK_NS);
    uint32_t fall_cycles = rnd_up_div(I2C_FALL_NS, SYSCLK_NS);
    uint32_t scl_period_cycles = rnd_up_div((10000 /* 10000 ns -> 100 kHz */), SYSCLK_NS);
    uint32_t scl_low_cycles = rnd_up_div(4700, SYSCLK_NS);
    uint32_t scl_high_cycles = scl_period_cycles - scl_low_cycles - rise_cycles - fall_cycles;
    DEV_WRITE(i2c + I2C_TIMING0_REG,
              (scl_low_cycles << I2C_TIMING0_TLOW) | (scl_high_cycles << I2C_TIMING0_THIGH));
    DEV_WRITE(i2c + I2C_TIMING1_REG,
              (fall_cycles << I2C_TIMING1_T_F) | (rise_cycles << I2C_TIMING1_T_R));
    DEV_WRITE(i2c + I2C_TIMING2_REG, (rnd_up_div(4000, SYSCLK_NS) << I2C_TIMING2_THD_STA) |
                                         (rnd_up_div(4700, SYSCLK_NS) << I2C_TIMING2_TSU_STA));
    DEV_WRITE(i2c + I2C_TIMING3_REG, ((1ul /* must be at least one */) << I2C_TIMING3_THD_DAT) |
                                         (rnd_up_div(250, SYSCLK_NS) << I2C_TIMING3_TSU_DAT));
    DEV_WRITE(i2c + I2C_TIMING4_REG, (rnd_up_div(4700, SYSCLK_NS) << I2C_TIMING4_T_BUF) |
                                         (rnd_up_div(4000, SYSCLK_NS) << I2C_TIMING4_TSU_STO));

    // -- Configure IP for Controller mode --
    DEV_WRITE(i2c + I2C_CTRL_REG, (1u << I2C_CTRL_ENABLEHOST));
}

bool i2c_write_byte(i2c_t i2c, uint8_t addr, uint8_t data)
{
    // Reset FMT FIFO (because we currently don't clean-up after errors)
    DEV_WRITE(i2c + I2C_FIFO_CTRL_REG, (1u << I2C_FIFO_CTRL_FMTRST));

    // Queue write request
    DEV_WRITE(i2c + I2C_FDATA_REG,
              ((1u << I2C_FDATA_START) | (((addr << 1) | 0u) << I2C_FDATA_FBYTE)));
    DEV_WRITE(i2c + I2C_FDATA_REG, ((1u << I2C_FDATA_STOP) | (data << I2C_FDATA_FBYTE)));

    // Wait for transaction to complete and report simple succeed/fail
    for (uint32_t ii = 0; ii < 10000000ul /*arbitrary number*/; ii++) {
        uint32_t intr_state = DEV_READ(i2c + I2C_INTR_STATE_REG);
        if (intr_state & (1u << I2C_INTR_STATE_CONTROLLER_HALT)) {
            return false; // transaction failed
        }
        if (intr_state & (1u << I2C_INTR_STATE_CMD_COMPLETE)) {
            if (DEV_READ(i2c + I2C_STATUS_REG) & (1u << I2C_STATUS_FMTEMPTY)) {
                return true; // transaction succeeded
            }
        }
    }
    return false; // timeout
}

uint8_t i2c_read_byte(i2c_t i2c, uint8_t addr)
{
    // Reset FMT FIFO (because we currently don't clean-up after errors)
    DEV_WRITE(i2c + I2C_FIFO_CTRL_REG, (1u << I2C_FIFO_CTRL_FMTRST));

    // Queue read request
    DEV_WRITE(i2c + I2C_FDATA_REG,
              ((1u << I2C_FDATA_START) | (((addr << 1) | 1u) << I2C_FDATA_FBYTE)));
    DEV_WRITE(i2c + I2C_FDATA_REG,
              ((1u << I2C_FDATA_READB) | (1u << I2C_FDATA_STOP) | (1u << I2C_FDATA_FBYTE)));

    // Wait for transaction to complete and return either read data or 0xFF
    for (uint32_t ii = 0; ii < 10000000ul /*arbitrary number*/; ii++) {
        if (DEV_READ(i2c + I2C_INTR_STATE_REG) & (1u << I2C_INTR_STATE_CONTROLLER_HALT)) {
            return 0xFF; // transaction failed
        }
        if (DEV_READ(i2c + I2C_STATUS_REG) & (1u << I2C_STATUS_FMTEMPTY)) {
            // transaction succeeded, return read data
            return DEV_READ(i2c + I2C_RDATA_REG);
        }
    }
    return 0xFF; // timeout
}
