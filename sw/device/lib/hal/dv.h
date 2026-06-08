// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Design Verification (DV) register window.

#pragma once

#include <stdint.h>

/* These values are written to the test_status register of the DV window
 * throughout a test to indicate test progression and outcome. */
enum dv_test_status : uint32_t {
    /* Test code has begun. */
    dv_test_status_in_test = 0x4354u,
    /* The test has passed. */
    dv_test_status_passed = 0x900du,
    /* The test has failed. */
    dv_test_status_failed = 0xbaadu,
};

/* These values are provided by the DV window from the hw_id register to
 * indicate the current test platform. */
enum dv_hwid : uint32_t {
    /* Running on the Genesys2 FPGA. */
    dv_hwid_fpga_genesys2 = 0xau,
    /* Running in a Verilator simulation. */
    dv_hwid_sim_verilator = 0x1au,
    /* Running in a UVM simulation. */
    dv_hwid_sim_uvm = 0x2au,
};

typedef volatile struct [[gnu::aligned(4)]] dv_window_memory_layout {
    /* test_status (0x0) */
    uint32_t test_status;

    /* hw_id (0x4) */
    const uint32_t hw_id;

    const uint8_t __reserved0[0x100 - 0x08];
} *dv_window_t;


_Static_assert(__builtin_offsetof(struct dv_window_memory_layout, test_status) == 0x0ul,
               "incorrect register test_status offset");
_Static_assert(__builtin_offsetof(struct dv_window_memory_layout, hw_id) == 0x4ul,
               "incorrect register hw_id offset");
