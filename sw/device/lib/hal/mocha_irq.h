// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Mocha IRQ mapping.

#pragma once

#include <stdint.h>

/* device IRQs at the PLIC */
enum [[clang::flag_enum]] mocha_system_irq : uint32_t {
    mocha_system_irq_invalid = (1u << 0),
    mocha_system_irq_unmapped_1 = (1u << 1),
    mocha_system_irq_unmapped_2 = (1u << 2),
    mocha_system_irq_unmapped_3 = (1u << 3),
    mocha_system_irq_unmapped_4 = (1u << 4),
    mocha_system_irq_unmapped_5 = (1u << 5),
    mocha_system_irq_i2c = (1u << 6),
    mocha_system_irq_spi_device = (1u << 7),
    mocha_system_irq_uart = (1u << 8),
    mocha_system_irq_gpio = (1u << 9),
    mocha_system_irq_pwrmgr = (1u << 10),
    mocha_system_irq_mailbox = (1u << 11),
    mocha_system_irq_unmapped_12 = (1u << 12),
    mocha_system_irq_unmapped_13 = (1u << 13),
    mocha_system_irq_unmapped_14 = (1u << 14),
    mocha_system_irq_unmapped_15 = (1u << 15),
    mocha_system_irq_unmapped_16 = (1u << 16),
    mocha_system_irq_unmapped_17 = (1u << 17),
    mocha_system_irq_unmapped_18 = (1u << 18),
    mocha_system_irq_unmapped_19 = (1u << 19),
    mocha_system_irq_unmapped_20 = (1u << 20),
    mocha_system_irq_unmapped_21 = (1u << 21),
    mocha_system_irq_unmapped_22 = (1u << 22),
    mocha_system_irq_unmapped_23 = (1u << 23),
    mocha_system_irq_unmapped_24 = (1u << 24),
    mocha_system_irq_unmapped_25 = (1u << 25),
    mocha_system_irq_unmapped_26 = (1u << 26),
    mocha_system_irq_unmapped_27 = (1u << 27),
    mocha_system_irq_unmapped_28 = (1u << 28),
    mocha_system_irq_unmapped_29 = (1u << 29),
    mocha_system_irq_unmapped_30 = (1u << 30),
    mocha_system_irq_unmapped_31 = (1u << 31),
};
