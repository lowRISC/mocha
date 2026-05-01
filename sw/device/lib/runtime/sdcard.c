// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/spi_host.h"
#include "hal/uart.h"
#include "hal/mmio.h"
#include "runtime/sdcard.h"
#include "runtime/print.h"
#include <stdbool.h>
#include <assert.h>
#include <stdint.h>


void deselect_card(spi_host_t spi) {
  // Use a eight-cycle transaction with CSAAT unset to deassert the Chip-Select line.
  // Using only one cycle seemed to screw-up the next transaction, so we use eight.
  nonblocking_cycles(spi, 8, false);
}

// Initialise the SD card ready for use.
bool init(spi_host_t spi, uart_t uart) {
  // Every card tried seems to be more than capable of keeping up with 20Mbps.
  const unsigned kSpiSpeed = 0u;
  DEV_WRITE(spi + SPI_HOST_CONFIGOPTS_REG,
            0xFFFF & kSpiSpeed);
  DEV_WRITE(spi + SPI_HOST_CONTROL_REG,
            SPI_HOST_CONTROL_SPIEN_MASK); // keep output_en low for now to disable Chip-Select

  // Apparently we're required to send at least 74 SD CLK cycles with
  // the device _not_ selected before talking to it.
  nonblocking_cycles(spi, 74, false);
  wait_idle(spi);

  DEV_WRITE(spi + SPI_HOST_CONTROL_REG,
            (SPI_HOST_CONTROL_SPIEN_MASK |
              SPI_HOST_CONTROL_OUTPUTEN_MASK)); // re-enable non-SCK outputs

  // Note that this is a very stripped-down card initialisation sequence
  // that assumes SDHC version 2, so use a more recent microSD card.
  do {
    send_command(spi, SDCARD_CMD_GO_IDLE_STATE, 0u, uart);
  } while (0x01 != get_response_R1(spi, uart));

  send_command(spi, SDCARD_CMD_SEND_IF_COND, 0x1aau, uart);
  get_response_R3(spi, uart);

  // Instruct the SD card whether to check CRC values on commands.
  send_command(spi, SDCARD_CMD_CRC_ON_OFF, (uint32_t)SDCARD_CRC_ON, uart);
  get_response_R1(spi, uart);

  // Read supported voltage range of the card.
  send_command(spi, SDCARD_CMD_READ_OCR, 0, uart);
  get_response_R3(spi, uart);

  do {
    send_command(spi, SDCARD_CMD_APP_CMD, 0, uart);
    (void)get_response_R1(spi, uart);
    // Specify Host Capacity Support as 1.
    send_command(spi, SDCARD_SD_SEND_OP_COND, 1u << 30, uart);
  } while (0x01 & get_response_R1(spi, uart));

  if (uart) {
    uprintf(uart, "Setting block length to 0x%x", SDCARD_BLOCK_LEN);
  }

  // Read card capacity information.
  send_command(spi, SDCARD_CMD_READ_OCR, 0, uart);
  get_response_R3(spi, uart);

  send_command(spi, SDCARD_CMD_SET_BLOCKLEN, SDCARD_BLOCK_LEN, uart);
  uint8_t rd = get_response_R1(spi, uart);
  if (uart) {
    uprintf(uart, "Response: 0x%x", rd);
  }
  deselect_card(spi);

  return true;
}

// Read Card Identification Data (CID).
bool read_cid(spi_host_t spi, uint8_t *buf, uint32_t len, uart_t uart) {
  return read_cid_csd(spi, SDCARD_CMD_SEND_CID, buf, len, uart);
}

// Read Card Specific Data (CSD).
bool read_csd(spi_host_t spi, uint8_t *buf, uint32_t len, uart_t uart) {
  return read_cid_csd(spi, SDCARD_CMD_SEND_CSD, buf, len, uart);
}

// Read a number of contiguous blocks from the SD card.
bool read_blocks(spi_host_t spi, uint32_t block, uint8_t *buf, uint32_t num_blocks, uart_t uart) {
  const bool multi = num_blocks > 1u;

  bool ok = true;
  for (uint32_t blk = 0u; blk < num_blocks; blk++) {
    if (uart) {
      uprintf(uart, "Reading block 0x%x\n", block + blk);
    }

    if (multi) {
      // Is this the first block of the read request?
      if (!blk) {
        send_command(spi, SDCARD_CMD_READ_MULTIPLE_BLOCK, block, uart);
        (void)get_response_R1(spi, uart);
      }
    } else {
      send_command(spi, SDCARD_CMD_READ_SINGLE_BLOCK, block + blk, uart);
      (void)get_response_R1(spi, uart);
    }

    if (!collected_data(spi, &buf[blk * SDCARD_BLOCK_LEN], SDCARD_BLOCK_LEN, uart)) {
      ok = false;
      break;
    }
  }

  if (multi) {
    send_command(spi, SDCARD_CMD_STOP_TRANSMISSION, 0u, uart);
    (void)get_response_R1b(spi, uart);
  }

  deselect_card(spi);
  return ok;
}

// Write a number of contiguous blocks from the SD card.
bool write_blocks(spi_host_t spi, uint32_t block, uint8_t *buf, uint32_t num_blocks, uart_t uart) {
  const bool multi = num_blocks > 1u;
  uint8_t crc16[2];
  crc16[1] = crc16[0] = 0xffu;  // CRC16 not required by default for SPI mode.

  bool ok = true;
  for (uint32_t blk = 0u; blk < num_blocks; blk++) {
    if (SDCARD_CRC_ON) {
      // CRC16 bytes follow the data block.
      uint16_t crc = calc_crc16(&buf[blk * SDCARD_BLOCK_LEN], SDCARD_BLOCK_LEN);
      crc16[0]     = (uint8_t)(crc >> 8);
      crc16[1]     = (uint8_t)crc;
    }
    if (uart) {
      uprintf(uart, "Writing block 0x%x\n", block + blk);
    }

    // Note: the Start Block Token differs between Multiple Block Write commands and
    // the other data transfer commands, including the Single Block Write command.
    uint8_t start_token;
    if (multi) {
      // Is this the first block of the read request?
      if (!blk) {
        send_command(spi, SDCARD_CMD_WRITE_MULTIPLE_BLOCK, block, uart);
        (void)get_response_R1(spi, uart);
      }
      start_token = SDCARD_START_BLOCK_TOKEN_MW;
    } else {
      send_command(spi, SDCARD_CMD_WRITE_SINGLE_BLOCK, block + blk, uart);
      (void)get_response_R1(spi, uart);
      start_token = SDCARD_START_BLOCK_TOKEN;
    }

    nonblocking_write(spi, &start_token, 1u);
    nonblocking_write(spi, &buf[blk * SDCARD_BLOCK_LEN], SDCARD_BLOCK_LEN);
    nonblocking_write(spi, crc16, sizeof(crc16));
    // Collect data_response and wait until the card is no longer busy.
    if (5 != (0x1f & get_data_response_busy(spi))) {
      // Data not accepted because of an error.
      ok = false;
      break;
    }
  }

  if (multi) {
    const uint8_t stop_tran_token = (uint8_t)SDCARD_STOP_TRAN_TOKEN;
    nonblocking_write(spi, &stop_tran_token, 1u);
    // The card will hold the CIPO line low whilst busy, yielding repeated 0x00 bytes,
    // but it seems to drop and raise the line at an arbitrary time with respect to
    // the '8-clock counting' logic.
    while (0x00 != get_response_byte(spi));  // Detect falling edge.
    // Card will signal busy with zeros.
    wait_not_busy(spi);
  }

  deselect_card(spi);
  return ok;
}

// Send a command to the SD card with the supplied 32-bit argument.
void send_command(spi_host_t spi, uint8_t cmdCode, uint32_t arg, uart_t uart) {
  uint8_t cmd[6];
  if (uart) {
    uprintf(uart, "Sending command 0x%x", cmdCode);
  }

  // Apparently we need to clock 8 times before sending the command.
  //
  // TODO: This may well be an issue with not aligning read data on the previous command?
  // Without this the initialisation sequence gets stuck trying to specify HCS; the SD card
  // does not become ready.
  nonblocking_cycles(spi, 8u, true);

  cmd[0] = 0x40u | cmdCode;
  cmd[1] = (uint8_t)(arg >> 24);
  cmd[2] = (uint8_t)(arg >> 16);
  cmd[3] = (uint8_t)(arg >> 8);
  cmd[4] = (uint8_t)(arg >> 0);
  // The final byte includes the CRC7 which _must_ be valid for two special commands,
  // but normally in SPI mode CRC checking is OFF.
  if (SDCARD_CRC_ON || cmdCode == SDCARD_CMD_GO_IDLE_STATE || cmdCode == SDCARD_CMD_SEND_IF_COND) {
    cmd[5] = 1u | (calc_crc7(cmd, 5) << 1);
  } else {
    // No need to expend CPU times calculating the CRC7; it will be ignored.
    cmd[5] = 0xffu;
  }
  nonblocking_write(spi, cmd, sizeof(cmd));
}

// Attempt to collect a single response byte from the device; if it is not driving the
// CIPO line we will read 0xff.
uint8_t get_response_byte(spi_host_t spi) {
  uint8_t r;
  read_card_data(spi, &r, 1u);
  return r;
}

// Get response type R1 from the SD card.
uint8_t get_response_R1(spi_host_t spi, uart_t uart) {
  wait_idle(spi);
  while (true) {
    uint8_t rd1 = get_response_byte(spi);
    // Whilst there is no response we read 0xff; an actual R1 response commences
    // with a leading 0 bit (MSB).
    if (!(rd1 & 0x80u)) {
      if (uart) {
        uprintf(uart, "R1 0x%x", rd1);
      }
      return rd1;
    }
  }
}

// Wait until the SD card declares that it is no longer busy.
inline void wait_not_busy(spi_host_t spi) {
  while (0x00 == get_response_byte(spi));  // Wait whilst device is busy.
}

// Get response type R1b from the SD card.
uint8_t get_response_R1b(spi_host_t spi, uart_t uart) {
  wait_idle(spi);
  uint8_t rd1 = get_response_R1(spi, uart);
  // Card may signal busy with zero bytes.
  wait_not_busy(spi);
  return rd1;
}

// Get data_response after sending a block of write data to the SD card.
uint8_t get_data_response_busy(spi_host_t spi) {
  uint8_t rd1;
  wait_idle(spi);
  do {
    rd1 = get_response_byte(spi);
  } while ((rd1 & 0x11u) != 0x01u);
  wait_not_busy(spi);
  return rd1;
}

// Get response type R3 (5 bytes) from the SD card.
void get_response_R3(spi_host_t spi, uart_t uart) {
  volatile uint8_t rd2;
  (void)get_response_R1(spi, uart);
  for (int r = 0; r < 4; ++r) {
    // Wait until SPI Host hardware is ready for a command
    while (!(DEV_READ(spi + SPI_HOST_STATUS_REG) & SPI_HOST_STATUS_READY_MASK)) {
    }
    // Program an RX command segment
    DEV_WRITE(spi + SPI_HOST_COMMAND_REG,
              ((1 << SPI_HOST_COMMAND_CSAAT_OFFSET) | SPI_HOST_COMMAND_DIRECTION_RECEIVE));
    wait_idle(spi);
    while (DEV_READ(spi + SPI_HOST_STATUS_REG) & SPI_HOST_STATUS_RXEMPTY_MASK) {
    }
    rd2 = (uint8_t)(DEV_READ(spi + SPI_HOST_RXDATA_REG));
  }
  // We need to ensure the FIFO reads occur, but we don't need the data presently.
  rd2 = rd2;
}

// Calculate the CRC7 value for a series of bytes (command/response);
// used to generate the CRC for a command or check that of a response if CRC_ON mode is used.
uint8_t calc_crc7(const uint8_t *data, uint32_t len) {
  uint8_t crc = 0u;
  while (len-- > 0u) {
    uint8_t d = *data++;
    for (unsigned b = 0u; b < 8u; b++) {
      crc = (crc << 1) ^ (((crc ^ d) & 0x80u) ? 0x12u : 0u);
      d <<= 1;
    }
  }
  // 7 MSBs contain the CRC residual.
  return crc >> 1;
}

// Calculate the CRC16 value for a series of bytes (data blocks);
// used for generation or checking, if CRC_ON mode is used.
uint16_t calc_crc16(const uint8_t *data, uint32_t len) {
  uint16_t crc = 0u;
  while (len-- > 0u) {
    uint16_t d = (uint16_t)*data++ << 8;
    for (unsigned b = 0u; b < 8u; b++) {
      crc = (crc << 1) ^ (((crc ^ d) & 0x8000u) ? 0x1021u : 0u);
      d <<= 1;
    }
  }
  return crc;
}

// Collect an expect number of bytes into the given buffer, and return an indication of whether
// they were collected without error.
static bool collected_data(spi_host_t spi, uint8_t *buf, uint32_t len, uart_t uart) {
  uint8_t crc16[2];

  // Collect the data, prepended with the Start Block Token and followed by the CRC16 bytes.
  while (SDCARD_START_BLOCK_TOKEN != get_response_byte(spi));
  // For at least one test card we need to hold the COPI line high during the data read
  // otherwise the data becomes corrupted; the card appears to be starting to accept a new
  // command.
  read_card_data(spi, buf, len);
  read_card_data(spi, crc16, sizeof(crc16));

  // Shall we validate the CRC16 of the received data block?
  if (SDCARD_CRC_ON) {
    uint16_t exp_crc16 = calc_crc16(buf, len);
    uint16_t obs_crc16 = ((uint16_t)crc16[0] << 8) | crc16[1];
    if (uart) {
      uprintf(uart, "Read block CRC 0x%x\n", obs_crc16);
      uprintf(uart, "Calculated CRC 0x%x\n", exp_crc16);
    }
    if (obs_crc16 != exp_crc16) {
      deselect_card(spi);
      if (uart) {
        uart_puts(uart, "CRC16 mismatch\n");
      }
      return false;
    }
  }
  return true;
}

// Shared implementation for SDCARD_CMD_SEND_CID and SDCARD_CMD_SEND_CSD.
static bool read_cid_csd(spi_host_t spi, uint8_t cmd, uint8_t *buf, uint32_t len, uart_t uart) {
  send_command(spi, cmd, 0, uart);
  (void)get_response_R1(spi, uart);
  bool ok = collected_data(spi, buf, len, uart);
  deselect_card(spi);
  return ok;
}

/*
  * Receives `len` bytes and puts them in the `data` buffer,
  * where `len` is at most `0x7ff`, being careful to keep COPI high by
  * also transmitting repeated 0xff bytes.
  *
  * This method will block until the requested number of bytes has been seen.
  * There is currently no timeout.
  *
  * Note that unlike the 'blocking_read' member function of the SPI object,
  * this function intentionally keeps the COPI line high by supplying a 0xff
  * byte for each byte read. This prevents COPI line dropping and being
  * misinterpreted as the start of a command.
  */
static void read_card_data(spi_host_t spi, uint8_t data[], uint32_t len) {
  assert((len-1) <= SPI_HOST_COMMAND_LEN_MAX);
  wait_idle(spi);
  // Do not attempt a zero-byte transfer; not supported by the controller.
  if (len) {
    // Wait until SPI Host hardware is ready for a command
    while (!(DEV_READ(spi + SPI_HOST_STATUS_REG) & SPI_HOST_STATUS_READY_MASK)) {
    }
    // Program an RX command segment
    DEV_WRITE(spi + SPI_HOST_COMMAND_REG,
              ((1 << SPI_HOST_COMMAND_CSAAT_OFFSET) | SPI_HOST_COMMAND_DIRECTION_RECEIVE |
                (((len-1) << SPI_HOST_COMMAND_LEN_OFF) & SPI_HOST_COMMAND_LEN_MASK)));
    // Pull data from the RX FIFO as it becomes available
    const uint8_t *end = data + len - 1;
    while (data <= end) {
      // Wait for data
      while (DEV_READ(spi + SPI_HOST_STATUS_REG) & SPI_HOST_STATUS_RXEMPTY_MASK) {
      }
      // Read a 32-bit RX FIFO word and pack relevant bytes into the destination array
      uint32_t data_word = DEV_READ(spi + SPI_HOST_RXDATA_REG);
      for (uint32_t by = 0; (by < 4) && (data <= end); by++) {
        *data++ = (uint8_t)(data_word);
        data_word >>= 8;
      }
    }
  }
}

/*
  * Poll the Status register until the Active flag has been cleared
  */
static void wait_idle(spi_host_t spi) {
  // One cycle of delay is needed to avoid a race condition when this
  // function is called directly after writing a command segment.
  __asm__("nop");
  while (SPI_HOST_STATUS_ACTIVE_MASK & DEV_READ(spi + SPI_HOST_STATUS_REG)) {
  }
}

/*
  * Program a directionless segment (SCK and CS, but no data RX or TX)
  * to be 'transmitted' by the SPI Host hardware.
  * This is that same as transmitting all-ones due to the way the
  * data output enable has been used in hardware.
  *
  * Note that length is specified in SCK cycles, rather than bytes.
  *
  * Leave the chip-select line asserted afterwards if `csaat` is set.
  */
static void nonblocking_cycles(spi_host_t spi, uint32_t cycles, bool csaat) {
  if (cycles) {
    // Wait until SPI Host hardware is ready for a command
    while (!(DEV_READ(spi + SPI_HOST_STATUS_REG) & SPI_HOST_STATUS_READY_MASK)) {
    }
    // Program a directionless command segment
    DEV_WRITE(spi + SPI_HOST_COMMAND_REG,
                ((csaat << SPI_HOST_COMMAND_CSAAT_OFFSET) |
                (((cycles-1) << SPI_HOST_COMMAND_LEN_OFF) & SPI_HOST_COMMAND_LEN_MASK)));
  }
}

/*
  * Program the transmission of `len` bytes starting with `data[0]`
  * by the SPI Host hardware.
  */
static void nonblocking_write(spi_host_t spi, const uint8_t data[], uint32_t len) {
  assert((len-1) <= SPI_HOST_COMMAND_LEN_MAX);
  // Wait until SPI Host hardware is ready for a command
  while (!(DEV_READ(spi + SPI_HOST_STATUS_REG) & SPI_HOST_STATUS_READY_MASK)) {
  }
  // Program a TX command segment.
  // Doing this before providing TX data avoids the TX FIFO size being a hard limit.
  DEV_WRITE(spi + SPI_HOST_COMMAND_REG,
            ((1 << SPI_HOST_COMMAND_CSAAT_OFFSET) | SPI_HOST_COMMAND_DIRECTION_TRANSMIT |
              (((len-1) << SPI_HOST_COMMAND_LEN_OFF) & SPI_HOST_COMMAND_LEN_MASK)));
  // Load TX data using a fast full-word loop followed by a slower clean-up loop.
  // The hope with the fast loop is
  uint32_t by = 0;
  uint32_t data_word;
  if (3 < len) {
    while (by < (len - 3u)) {
      // Prepare a full 32-bit word of data
      data_word  = data[by];
      data_word |= data[by+1] << 8;
      data_word |= data[by+2] << 16;
      data_word |= data[by+3] << 24;
      // Wait for TX FIFO space
      while (DEV_READ(spi + SPI_HOST_STATUS_REG) & SPI_HOST_STATUS_TXFULL_MASK) {
      }
      // Write data to the SPI Host TX FIFO
      DEV_WRITE(spi + SPI_HOST_TXDATA_REG, data_word);
      by += 4;
    }
  }
  if (by < len) {
    // Prepare a partial word containing remaining data
    data_word = data[by];
    if (len & 0x2) {
      data_word |= data[by+1] << 8;
      if (len & 0x1) {
        data_word |= data[by+2] << 16;
      }
    }
    // Wait for TX FIFO space
    while (DEV_READ(spi + SPI_HOST_STATUS_REG) & SPI_HOST_STATUS_TXFULL_MASK) {
    }
    // Write data to the SPI Host TX FIFO
    DEV_WRITE(spi + SPI_HOST_TXDATA_REG, data_word);
  }
}
