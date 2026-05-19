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

    // Calculate the timing paramters
    uint32_t rise_cycles = rnd_up_div(I2C_RISE_NS, SYSCLK_NS);
    uint32_t fall_cycles = rnd_up_div(I2C_FALL_NS, SYSCLK_NS);
    uint32_t scl_period_cycles = rnd_up_div((10000 /* 10000 ns -> 100 kHz */), SYSCLK_NS);
    uint32_t scl_low_cycles = rnd_up_div(4700, SYSCLK_NS);
    uint32_t scl_high_cycles = scl_period_cycles - scl_low_cycles - rise_cycles - fall_cycles;
    uint32_t setup_start_cycles = rnd_up_div(4700, SYSCLK_NS);
    uint32_t hold_start_cycles = rnd_up_div(4000, SYSCLK_NS);
    uint32_t setup_data_cycles = rnd_up_div(250, SYSCLK_NS);
    uint32_t hold_data_cycles = 1u;
    uint32_t setup_stop_cycles = rnd_up_div(4000, SYSCLK_NS);
    uint32_t bus_free_time_cycles = rnd_up_div(4700, SYSCLK_NS);

    // Declare timing registers
    i2c_timing0 t0_reg = { .tlow = scl_low_cycles, .thigh = scl_high_cycles };
    i2c_timing1 t1_reg = { .t_r = rise_cycles, .t_f = fall_cycles };
    i2c_timing2 t2_reg = { .tsu_sta = setup_start_cycles, .thd_sta = hold_start_cycles };
    i2c_timing3 t3_reg = { .tsu_dat = setup_data_cycles, .thd_dat = hold_data_cycles };
    i2c_timing4 t4_reg = { .tsu_sto = setup_stop_cycles, .t_buf = bus_free_time_cycles };

    VOLATILE_WRITE(i2c->timing0, t0_reg);
    VOLATILE_WRITE(i2c->timing1, t1_reg);
    VOLATILE_WRITE(i2c->timing2, t2_reg);
    VOLATILE_WRITE(i2c->timing3, t3_reg);
    VOLATILE_WRITE(i2c->timing4, t4_reg);
}

void i2c_write_bytes(i2c_t i2c, uint8_t addr, const uint8_t *data, uint8_t num_bytes)
{
    // Reset the FMT FIFO as a precautionary step in case something goes wrong when controller's FSM
    // is halted and the SW didn't manage to clear the FIFO during that scenario.
    i2c_fifo_ctrl fifo_ctrl_reg = { .fmtrst = 1u };
    VOLATILE_WRITE(i2c->fifo_ctrl, fifo_ctrl_reg);

    // Queue write request
    //
    // Send start bit, address and R/W bit first
    i2c_fdata fdata_reg = { 0 };
    fdata_reg.fbyte = addr << 1u; // fbyte[7:1] = addr; fbyte[0] = 0 -> write
    fdata_reg.start = 1u;
    VOLATILE_WRITE(i2c->fdata, fdata_reg);

    fdata_reg.start = 0;

    for (uint8_t i = 0; i < num_bytes; i++) {
        // Check the overflow condition first before writing to the FMT FIFO by waiting until FMT
        // FIFO has some space
        while (VOLATILE_READ(i2c->status) & i2c_status_fmtfull) {
        }

        // Send all data bytes; assert STOP only on the last byte
        fdata_reg.fbyte = data[i];
        if (i == (num_bytes - 1u)) {
            fdata_reg.stop = 1u;
        }
        VOLATILE_WRITE(i2c->fdata, fdata_reg);
    }
}

void i2c_read_bytes(i2c_t i2c, uint8_t addr, uint8_t num_bytes)
{
    // Reset the FMT FIFO as a precautionary step in case something goes wrong when controller's FSM
    // is halted and the SW didn't manage to clear the FIFO during that scenario.
    i2c_fifo_ctrl fifo_ctrl_reg = { .fmtrst = 1u };
    VOLATILE_WRITE(i2c->fifo_ctrl, fifo_ctrl_reg);

    // Queue read request
    //
    // Send start bit, address and R/W bit first
    i2c_fdata fdata_reg = { 0 };
    fdata_reg.fbyte = (addr << 1u) | 1u; // fbyte[7:1] = addr; fbyte[0] = 1 -> read
    fdata_reg.start = 1u;
    VOLATILE_WRITE(i2c->fdata, fdata_reg);

    // Send stop bit, read bit and number of bytes to read
    fdata_reg.readb = 1u;
    fdata_reg.fbyte = num_bytes; // If readb = 1 then fbyte contains the number of bytes to read
    fdata_reg.start = 0;
    fdata_reg.stop = 1u;
    VOLATILE_WRITE(i2c->fdata, fdata_reg);
}

bool i2c_wait_write_finish(i2c_t i2c)
{
    // Wait for transaction to complete and report simple succeed / fail
    while (true) {
        i2c_intr i2c_intr_state_reg = VOLATILE_READ(i2c->intr_state);
        if (i2c_intr_state_reg & i2c_intr_controller_halt) {
            // Reset FMT FIFO as controller's FSM is in halt
            i2c_fifo_ctrl fifo_ctrl_reg = { .fmtrst = 1u };
            VOLATILE_WRITE(i2c->fifo_ctrl, fifo_ctrl_reg);

            // According to programmer's guide, the CONTROLLER_EVENTS register would be cleared
            // here to acknowledge the controller halt interrupt. However, since we want to
            // treat a halt event as a failure, we intentionally skip clearing it.
            return false; // Transaction failed
        }
        if (i2c_intr_state_reg & i2c_intr_cmd_complete) {
            i2c_status i2c_status_reg = VOLATILE_READ(i2c->status);
            if (i2c_status_reg & i2c_status_fmtempty) {
                return true; // Transaction succeeded
            }
        }
    }
}

bool i2c_wait_read_finish(i2c_t i2c)
{
    // Wait for transaction to complete and report simple succeed / fail
    while (true) {
        i2c_intr i2c_intr_state_reg = VOLATILE_READ(i2c->intr_state);
        if (i2c_intr_state_reg & i2c_intr_controller_halt) {
            // Reset FMT FIFO as controller's FSM is in halt
            i2c_fifo_ctrl fifo_ctrl_reg = { .fmtrst = 1u };
            VOLATILE_WRITE(i2c->fifo_ctrl, fifo_ctrl_reg);

            // According to programmer's guide, the CONTROLLER_EVENTS register would be cleared
            // here to acknowledge the controller halt interrupt. However, since we want to
            // treat a halt event as a failure, we intentionally skip clearing it.
            return false; // Transaction failed
        }
        i2c_status i2c_status_reg = VOLATILE_READ(i2c->status);
        if (i2c_status_reg & i2c_status_fmtempty) {
            return true;
        }
    }
}

void enable_controller_mode(i2c_t i2c)
{
    VOLATILE_WRITE(i2c->ctrl, i2c_ctrl_enablehost);
}

uint8_t i2c_rdata_byte(i2c_t i2c)
{
    i2c_rdata rdata_reg = VOLATILE_READ(i2c->rdata);
    return rdata_reg.rdata;
}
