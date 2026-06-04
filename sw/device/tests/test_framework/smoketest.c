// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/dv.h"
#include "hal/mocha.h"
#include "hal/uart.h"
#include <stdbool.h>

bool test_main(uart_t console)
{
    dv_window_t dv_window = mocha_system_dv_window();
    uint32_t hwid = DEV_READ(&dv_window->hw_id);

    uart_puts(console, "Test framework smoketest\n");

    switch (hwid) {
    case dv_hwid_fpga_genesys2:
        uart_puts(console, "Platform: Genesys2 FPGA\n");
        break;
    case dv_hwid_sim_verilator:
        uart_puts(console, "Platform: Verilator Simulation\n");
        break;
    case dv_hwid_sim_uvm:
        uart_puts(console, "Platform: UVM Simulation\n");
        break;
    default:
        uart_puts(console, "Unknown Hardware ID\n");
        return false;
    }

    return true;
}
