// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/mocha.h"
#include "hal/uart.h"
#include "runtime/print.h"
#if defined(__riscv_zcherihybrid)
#include <cheriintrin.h>
#endif /* defined(__riscv_zcherihybrid) */

// This test expects a test binary to be loaded into DRAM.
// This will just jump to the start of that test.

bool test_main(void)
{
    uart_t console = mocha_system_uart();
    uart_init(console);

    enum : uint64_t { boot_vector = dram_base + 0x80 };
    uprintf(console, "jumping to DRAM boot vector: %lx\n", boot_vector);

    void (*boot)(void) = (void (*)(void))boot_vector;
    boot();

    /* Test in DRAM should have succeeded and terminated the test */
    return false;
}
