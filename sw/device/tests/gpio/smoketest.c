// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/gpio.h"
#include "hal/mmio.h"
#include "hal/mocha.h"
#include <stdbool.h>
#include <stdint.h>

// Drive a pattern (val)
static void drive(gpio_t gpio, uint32_t masked_reg, uint32_t val)
{
    gpio_write(gpio, masked_reg, 0XFFFF0000 | val);
}

// Wait for an expected pattern (compare_val).
static void wait(gpio_t gpio, uint32_t compare_val)
{
    while (DEV_READ(gpio + GPIO_REG_DATA_IN) != compare_val) {
    }
}

// Verifies GPIOs in partially output and input direction. The test distributes GPIOs as four equal
// quarters. The idea is to drive first quarter of GPIOs as outputs and wait for a pattern to appear
// on the second quarter of pins as inputs. Next, drive a pattern on the third quarter and waits for a
// pattern to appear on the fourth quarter as inputs. Repeat the same process second time but with a
// different pattern.
//
// The pattern driven on the outputs is going to be walking 1's (1, 10, 0100, 1000, ...) first and
// then walking 0's (1110, 1101, 1011, 0111, ...) whereas it is all 1's then all 0's sequence for
// the inputs.
//
// 1- Walk 1's on the first quarter of GPIOs in output mode.
// 2- top_chip_dv_gpio_base_vseq will wait for walking 1's pattern to appear on the pads. Once it
//    sees that pattern, it will drive all 1's on to the second quarter.
// 4- gpio_test waits for the pattern 0x0000FF80 on the GPIO pads by reading DATA_IN register. Then
//    it will walk 1's on the third quarter of pins and waits for pattern 0xFF80FF80.
// 5- On the other side, the vseq waits for the walking 1's pattern on the third quarter of pins and
//    drive all 1's on the fourth quarter.
// 6- After all that, gpio_test start to write 1's to the first and third quarter of pins in order to
//    drive walking 0's. Everything beyond that is similar but the expected driven sequence is going
//    to be 0's on the inputs and walking 0's on the outputs.
static bool gpio_test(gpio_t gpio)
{
    // Enable the first and third quarter of pins in output mode
    gpio_set_all_oe(gpio, 0x00FF00FF);

    // Current GPIOs pads state : 0x00000000
    //
    // Walk 1's on the first quarter. vseq drives the second quarter with all 1's. Hence, the
    // expected value to wait for is 0xFF80,
    for (int i = 0; i < GPIO_NUM_PINS / 4; i++) {
        drive(gpio, GPIO_REG_MASKED_OUT_LOWER, 1 << i);
        if (i == ((GPIO_NUM_PINS / 4) - 1)) {
            wait(gpio, 0xFF80);
        }
    }

    // Current GPIOs pads state : 0x0000FF80
    //
    // Walk 1's on the third quarter. vseq drives the fourth quarter with all 1's. Additionally, the
    // pads contains 0xFF80 by now on the first two quarters. Hence, the expected value to wait for
    // is 0xFF80FF80,
    for (int i = 0; i < GPIO_NUM_PINS / 4; i++) {
        drive(gpio, GPIO_REG_MASKED_OUT_UPPER, 1 << i);
        if (i == ((GPIO_NUM_PINS / 4) - 1)) {
            wait(gpio, 0xFF80FF80);
        }
    }

    // Current GPIOs pads state : 0xFF80FF80
    //
    // Now, set the first and third quarter (which are enabled as outputs) to all 1's in order to
    // walk 0's on them.
    gpio_write(gpio, GPIO_REG_DIRECT_OUT, 0x00FF00FF);

    // Current GPIOs pads state : 0xFFFFFFFF
    //
    // Walk 0's on the first quarter of pins. vseq drives the second quarter with all 0's.
    // Hence, the expected value to wait for is 0xFFFF007F.
    for (int i = 0; i < GPIO_NUM_PINS / 4; i++) {
        drive(gpio, GPIO_REG_MASKED_OUT_LOWER, ~(1 << i));
        if (i == ((GPIO_NUM_PINS / 4) - 1)) {
            wait(gpio, 0xFFFF007F);
        }
    }

    // Current GPIOs pads state : 0xFFFF007F
    //
    // Walk 0's on the third quarter of pins. vseq drives the fourth quarter with all 0's.
    // Hence, the expected value to wait for is 0x007F007F.
    for (int i = 0; i < GPIO_NUM_PINS / 4; i++) {
        drive(gpio, GPIO_REG_MASKED_OUT_UPPER, ~(1 << i));
        if (i == ((GPIO_NUM_PINS / 4) - 1)) {
            wait(gpio, 0x007F007F);
        }
    }

    // Current GPIOs pads state : 0x007F007F

    return true;
}

bool test_main()
{
    gpio_t gpio = mocha_system_gpio();
    return gpio_test(gpio);
}
