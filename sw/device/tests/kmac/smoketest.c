// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/* Connectivity smoke test for the KMAC block.
 *
 * Software cannot reach KMAC directly in Mocha: its register interface is tied
 * off at the top level. Its only live connection is to rom_ctrl, which uses it
 * to hash the boot ROM at power-on.
 *
 * The hash is produced twice. At build time scramble_image.py hashes the ROM
 * image and stores the result in the top 8 words of that image. At power-on
 * rom_ctrl reads the ROM back, sends everything below those 8 words to KMAC,
 * and gets a freshly computed hash in return. rom_ctrl holds the stored copy in
 * exp_digest and the computed one in digest, and only lets the CPU start if the
 * two match. Mocha never bypasses that check, because lc_dft_en_i is hardwired
 * off; upstream OpenTitan does bypass it in TEST and RMA. Running at all
 * therefore already means the hashes agreed.
 *
 * That also limits what this test can find. If the hashes had disagreed, or if
 * rom_ctrl had reported a fault, the CPU would never have started and this code
 * would never run. The simulation would simply time out. So the checks below
 * only ever see the case where everything already worked.
 *
 * What they can find is a fault in reading the registers back out. rom_ctrl
 * compares the values it stored, so if storing them were broken the chip would
 * not boot at all. But if only the read path is wrong, say the wrong address or
 * the words in the wrong order, the chip boots normally while software sees the
 * wrong values. Comparing the two registers here catches that.
 */

#include "builtin.h"
#include "hal/mocha.h"
#include "hal/rom_ctrl.h"
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

static bool rom_digest_test(rom_ctrl_t rom_ctrl)
{
    uint32_t any_bit_set = 0;
    uint32_t any_bit_clear = 0;

    for (size_t i = 0; i < ARRAY_LEN(rom_ctrl->digest); i++) {
        uint32_t digest = rom_ctrl_digest_read(rom_ctrl, i);

        // Check that all the digests match the expected
        if (digest != rom_ctrl_exp_digest_read(rom_ctrl, i)) {
            return false;
        }

        // Check if the digest was all 0s or all 1s
        any_bit_set |= digest;
        any_bit_clear |= ~digest;
    }

    return any_bit_set != 0 && any_bit_clear != 0;
}

bool test_main()
{
    rom_ctrl_t rom_ctrl = mocha_system_rom_ctrl();

    if (rom_ctrl_fatal_alert_cause_read(rom_ctrl) != rom_ctrl_fatal_alert_cause_none) {
        return false;
    }

    return rom_digest_test(rom_ctrl);
}
