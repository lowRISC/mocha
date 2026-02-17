// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include <stdint.h>

#define FRAME_BUFFER_WIDTH (512)
#define FRAME_BUFFER_HEIGHT (1024)
#define FRAME_BUFFER_BYTES_PER_PIXEL (2)

typedef void *frame_buffer_t;

void frame_buffer_write_pixel_565(frame_buffer_t frame_buffer, uint16_t x, uint16_t y, uint8_t r, uint8_t g, uint8_t b);
