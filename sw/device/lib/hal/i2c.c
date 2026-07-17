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

uint16_t i2c_calc_scl_high_cycles(uint16_t rise_cycles, uint16_t fall_cycles,
                                  uint16_t scl_period_cycles, uint16_t scl_low_cycles,
                                  uint16_t scl_high_cycles_min)
{
    // scl_high_time should be at least 4 cycles to aid correct clock stretching
    scl_high_cycles_min = (scl_high_cycles_min < 4u) ? 4u : scl_high_cycles_min;

    // An SCL period duration is divided into 4 segments:
    // 1) Rise time
    // 2) Fall time
    // 3) High time
    // 4) Low time
    // Hence an SCL period must satisfy the equation below:
    // scl_period = rise_time + fall_time + high_time + low_time
    //
    // Even though SCL_low_cycles and SCL_high_cycles have minimum allowable values, increase in
    // rise time and fall time influences the SCL_period.
    uint16_t scl_high_cycles = scl_period_cycles - (scl_low_cycles + rise_cycles + fall_cycles);

    scl_high_cycles =
        (scl_high_cycles > scl_high_cycles_min) ? scl_high_cycles : scl_high_cycles_min;

    return scl_high_cycles;
}

// Calculate the minimum allowable value for each timing parameter taken from the NXP I^2C
// specification "UM10204" Table 10 (rev. 6) / Table 11 (rev. 7).
//
// The values for Rise and Fall times for Fast mode are taken as spec minimum. For Fast plus mode,
// the values are taken from OpenTitan's i2c_host_tx_rx_test.c test.
static i2c_timing_params_t compute_minimum_timing_parameters(i2c_speed_mode_t speed)
{
    switch (speed) {
    case i2c_speed_mode_standard:
        return (i2c_timing_params_t){
            .rise_cycles = rnd_up_div(I2C_RISE_NS, SYSCLK_NS),
            .fall_cycles = rnd_up_div(I2C_FALL_NS, SYSCLK_NS),
            .scl_low_cycles = rnd_up_div(4700, SYSCLK_NS),
            .scl_high_cycles = rnd_up_div(4000, SYSCLK_NS),
            .scl_period_cycles = rnd_up_div(10000u, SYSCLK_NS),
            .setup_start_cycles = rnd_up_div(4700u, SYSCLK_NS),
            .hold_start_cycles = rnd_up_div(4000u, SYSCLK_NS),
            .setup_data_cycles = rnd_up_div(250u, SYSCLK_NS),
            .hold_data_cycles = 1u,
            .setup_stop_cycles = rnd_up_div(4000u, SYSCLK_NS),
            .bus_free_cycles = rnd_up_div(4700u, SYSCLK_NS)
        };
    case i2c_speed_mode_fast:
        return (i2c_timing_params_t){
            .rise_cycles = rnd_up_div(20u, SYSCLK_NS),
            .fall_cycles = rnd_up_div(20u, SYSCLK_NS),
            .scl_low_cycles = rnd_up_div(1300u, SYSCLK_NS),
            .scl_high_cycles = rnd_up_div(600, SYSCLK_NS),
            .scl_period_cycles = rnd_up_div(2500u, SYSCLK_NS),
            .setup_start_cycles = rnd_up_div(600u, SYSCLK_NS),
            .hold_start_cycles = rnd_up_div(600u, SYSCLK_NS),
            .setup_data_cycles = rnd_up_div(100u, SYSCLK_NS),
            .hold_data_cycles = 1u,
            .setup_stop_cycles = rnd_up_div(600u, SYSCLK_NS),
            .bus_free_cycles = rnd_up_div(1300u, SYSCLK_NS)
        };
    case i2c_speed_mode_fast_plus:
        return (i2c_timing_params_t){
            .rise_cycles = rnd_up_div(10u, SYSCLK_NS),
            .fall_cycles = rnd_up_div(10u, SYSCLK_NS),
            .scl_low_cycles = rnd_up_div(500u, SYSCLK_NS),
            .scl_high_cycles = rnd_up_div(260, SYSCLK_NS),
            .scl_period_cycles = rnd_up_div(1000u, SYSCLK_NS),
            .setup_start_cycles = rnd_up_div(260u, SYSCLK_NS),
            .hold_start_cycles = rnd_up_div(260u, SYSCLK_NS),
            .setup_data_cycles = rnd_up_div(50, SYSCLK_NS),
            .hold_data_cycles = 1u,
            .setup_stop_cycles = rnd_up_div(260u, SYSCLK_NS),
            .bus_free_cycles = rnd_up_div(500u, SYSCLK_NS)
        };
    default:
        return (i2c_timing_params_t){ 0 };
    }
}

void i2c_init(i2c_t i2c, i2c_speed_mode_t speed_mode)
{
    i2c_timing_params_t timing_params = compute_minimum_timing_parameters(speed_mode);

    timing_params.scl_high_cycles =
        i2c_calc_scl_high_cycles(timing_params.rise_cycles, timing_params.fall_cycles,
                                 timing_params.scl_period_cycles, timing_params.scl_low_cycles,
                                 timing_params.scl_high_cycles);

    // Declare timing registers
    i2c_timing0 t0_reg = { .tlow = timing_params.scl_low_cycles,
                           .thigh = timing_params.scl_high_cycles };
    i2c_timing1 t1_reg = { .t_r = timing_params.rise_cycles, .t_f = timing_params.fall_cycles };
    i2c_timing2 t2_reg = { .tsu_sta = timing_params.setup_start_cycles,
                           .thd_sta = timing_params.hold_start_cycles };
    i2c_timing3 t3_reg = { .tsu_dat = timing_params.setup_data_cycles,
                           .thd_dat = timing_params.hold_data_cycles };
    i2c_timing4 t4_reg = { .tsu_sto = timing_params.setup_stop_cycles,
                           .t_buf = timing_params.bus_free_cycles };

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

bool i2c_host_wait_transfer_finish(i2c_t i2c)
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
            if (VOLATILE_READ(i2c->status) & i2c_status_fmtempty) {
                return true; // Transaction succeeded
            }
        }
    }
}

void i2c_enable_controller_mode(i2c_t i2c)
{
    VOLATILE_WRITE(i2c->ctrl, i2c_ctrl_enablehost);
}

uint8_t i2c_rdata_byte(i2c_t i2c)
{
    i2c_rdata rdata_reg = VOLATILE_READ(i2c->rdata);
    return rdata_reg.rdata;
}
