/* Copyright lowRISC and contributors (COSMIC project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/* The bootrom image of this build, BOOTROM_BIN, and its size in bytes */

.section .rodata

.balign 8
.global rom_ctrl_bootrom_image
.type rom_ctrl_bootrom_image, @object
rom_ctrl_bootrom_image:
    .incbin BOOTROM_BIN
rom_ctrl_bootrom_image_end:
.size rom_ctrl_bootrom_image, rom_ctrl_bootrom_image_end - rom_ctrl_bootrom_image

.balign 8
.global rom_ctrl_bootrom_image_size
.type rom_ctrl_bootrom_image_size, @object
rom_ctrl_bootrom_image_size:
    .dword rom_ctrl_bootrom_image_end - rom_ctrl_bootrom_image
.size rom_ctrl_bootrom_image_size, 8
