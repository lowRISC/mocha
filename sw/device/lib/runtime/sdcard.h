// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include "hal/mmio.h"
#include "hal/uart.h"
#include <stdbool.h>
#include <stdint.h>

// Compile-switches for sdcard-utils code.
// - Enable/disable CRC checking on SD Card traffic
#define SDCARD_CRC_ON true

// Transfers in SPI mode are always in terms of 512-byte blocks.
#define SDCARD_BLOCK_LEN (512u)

// SD command codes. (Section 7.3.1)
#define SDCARD_CMD_GO_IDLE_STATE         (0u)
#define SDCARD_CMD_SEND_OP_COND          (1u)
#define SDCARD_CMD_SEND_IF_COND          (8u)
#define SDCARD_CMD_SEND_CSD              (9u)
#define SDCARD_CMD_SEND_CID             (10u)
#define SDCARD_CMD_STOP_TRANSMISSION    (12u)
#define SDCARD_CMD_SET_BLOCKLEN         (16u)
#define SDCARD_CMD_READ_SINGLE_BLOCK    (17u)
#define SDCARD_CMD_READ_MULTIPLE_BLOCK  (18u)
#define SDCARD_CMD_WRITE_SINGLE_BLOCK   (24u)
#define SDCARD_CMD_WRITE_MULTIPLE_BLOCK (25u)
#define SDCARD_SD_SEND_OP_COND          (41u)
#define SDCARD_CMD_APP_CMD              (55u)
#define SDCARD_CMD_READ_OCR             (58u)
#define SDCARD_CMD_CRC_ON_OFF           (59u)

// SD Control Tokens. (Section 7.3.3)
// Start Block Token precedes data block, for all but Multiple Block Write.
#define SDCARD_START_BLOCK_TOKEN    (0xfeu)
// Start Block Token used for Multiple Block Write operations.
#define SDCARD_START_BLOCK_TOKEN_MW (0xfcu)
// Stop Transaction Token, for Multiple Block Writes.
#define SDCARD_STOP_TRAN_TOKEN      (0xfdu)

// 'Public' function declarations
void deselect_card(spi_host_t spi);
bool init(spi_host_t spi, uart_t uart = NULL);
bool read_cid(spi_host_t spi, uint8_t *buf, uint32_t len, uart_t uart = NULL);
bool read_csd(spi_host_t spi, uint8_t *buf, uint32_t len, uart_t uart = NULL);
bool read_blocks(spi_host_t spi, uint32_t block, uint8_t *buf, uint32_t num_blocks, uart_t uart = NULL);
bool write_blocks(spi_host_t spi, uint32_t block, uint8_t *buf, uint32_t num_blocks, uart_t uart = NULL);
void send_command(spi_host_t spi, uint8_t cmdCode, uint32_t arg, uart_t uart = NULL);
uint8_t get_response_byte(spi_host_t spi);
uint8_t get_response_R1(spi_host_t spi, uart_t uart = NULL);
void wait_not_busy(spi_host_t spi);
uint8_t get_response_R1b(spi_host_t spi, uart_t uart = NULL);
uint8_t get_data_response_busy(spi_host_t spi);
void get_response_R3(spi_host_t spi, uart_t uart = NULL);
uint8_t calc_crc7(const uint8_t *data, uint32_t len);
uint16_t calc_crc16(const uint8_t *data, uint32_t len);

// 'Private' function declarations
static bool collected_data(spi_host_t spi, uint8_t *buf, uint32_t len, uart_t uart = NULL);
static bool read_cid_csd(spi_host_t spi, uint8_t cmd, uint8_t *buf, uint32_t len, uart_t uart = NULL);
static void read_card_data(spi_host_t spi, uint8_t data[], uint32_t len);
static void wait_idle(spi_host_t spi);
static void nonblocking_cycles(spi_host_t spi, uint32_t cycles, bool csaat);
static void nonblocking_write(spi_host_t spi, const uint8_t data[], uint32_t len);
