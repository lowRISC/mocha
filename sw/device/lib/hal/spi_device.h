// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include "autogen/spi_device.h"
#include <stdbool.h>
#include <stdint.h>

#define SPI_DEVICE_READ_BUFFER_NUM_BYTES (2048)
#define SPI_DEVICE_SFDP_AREA_OFFSET      (0xC00)
#define SPI_DEVICE_SFDP_AREA_NUM_BYTES   (256)

#define SPI_DEVICE_PAYLOAD_AREA_NUM_BYTES (256)

#define SPI_DEVICE_CMD_ADDR_MODE_ADDR_DISABLED (0x0)
#define SPI_DEVICE_CMD_ADDR_MODE_ADDR_CFG      (0x1)
#define SPI_DEVICE_CMD_ADDR_MODE_ADDR_3B       (0x2)
#define SPI_DEVICE_CMD_ADDR_MODE_ADDR_4B       (0x3)

#define SPI_DEVICE_SFDP_SIGNATURE      (0x50444653)
#define SPI_DEVICE_SFDP_MINOR_REVISION (0x0A)
#define SPI_DEVICE_SFDP_MAJOR_REVISION (0x01)
#define SPI_DEVICE_SFDP_PARAM_COUNT    (0)
// 3-byte addressing for SFDP_READ command, 8 wait states (JESD216F 6.2.3)
#define SPI_DEVICE_SFDP_ACCESS_PROTOCOL (0xFF)

#define SPI_DEVICE_BFPT_MINOR_REVISION (0x07)
#define SPI_DEVICE_BFPT_MAJOR_REVISION (0x01)
#define SPI_DEVICE_BFPT_PARAM_ID_LSB   (0x00)
#define SPI_DEVICE_BFPT_PARAM_ID_MSB   (0xFF)
#define SPI_DEVICE_BFPT_NUM_WORDS      (23)

#define SPI_DEVICE_OPCODE_PAGE_PROGRAM   (0x02)
#define SPI_DEVICE_OPCODE_PAGE_PROGRAM4B (0x12)
#define SPI_DEVICE_OPCODE_READ_DATA      (0x03)
#define SPI_DEVICE_OPCODE_WRITE_DISABLE  (0x04)
#define SPI_DEVICE_OPCODE_READ_STATUS    (0x05)
#define SPI_DEVICE_OPCODE_WRITE_ENABLE   (0x06)
#define SPI_DEVICE_OPCODE_SECTOR_ERASE   (0x20)
#define SPI_DEVICE_OPCODE_SECTOR_ERASE4B (0x21)
#define SPI_DEVICE_OPCODE_READ_SFDP      (0x5A)
#define SPI_DEVICE_OPCODE_RESET          (0x99)
#define SPI_DEVICE_OPCODE_READ_JEDEC_ID  (0x9F)
#define SPI_DEVICE_OPCODE_ENTER_4B_ADDR  (0xB7)
#define SPI_DEVICE_OPCODE_CHIP_ERASE     (0xC7)

#define MOCHA_SPI_DEVICE_JEDEC_CC           (0x7F)
#define MOCHA_SPI_DEVICE_JEDEC_CC_COUNT     (0)
#define MOCHA_SPI_DEVICE_ROM_BOOTSTRAP      (true)
#define MOCHA_SPI_DEVICE_CHIP_REV           (0)
#define MOCHA_SPI_DEVICE_CHIP_GEN           (0)
#define MOCHA_SPI_DEVICE_DENSITY_BITS       ((1 << 20) * 8)
#define MOCHA_SPI_DEVICE_DENSITY_BYTES_LOG2 (20)
#define MOCHA_SPI_DEVICE_MANUFACTURER_ID    (0xef)

typedef enum spi_device_status {
    spi_device_status_ready = 0,
    spi_device_status_empty = 1,
    spi_device_status_overflow = 2,
} spi_device_status_t;

typedef struct spi_device_cmd {
    spi_device_status_t status;
    uint8_t opcode;
    uint16_t payload_byte_count;
    uint32_t address;
} spi_device_cmd_t;

/* interrupts */
bool spi_device_interrupt_any_pending(spi_device_t spi_device, spi_device_intr intrs);
void spi_device_interrupt_clear(spi_device_t spi_device, spi_device_intr intrs);
void spi_device_interrupt_enable_write(spi_device_t spi_device, spi_device_intr intrs);
void spi_device_interrupt_enable_set(spi_device_t spi_device, spi_device_intr intrs);
void spi_device_interrupt_enable_clear(spi_device_t spi_device, spi_device_intr intrs);
void spi_device_interrupt_force(spi_device_t spi_device, spi_device_intr intrs);

/* control */
void spi_device_enable_set(spi_device_t spi_device, bool enable);
void spi_device_4b_addr_mode_enable_set(spi_device_t spi_device, bool enable);
bool spi_device_4b_addr_mode_enable_get(spi_device_t spi_device);

/* flash status */
void spi_device_flash_status_set(spi_device_t spi_device, uint32_t flash_status);
uint32_t spi_device_flash_status_get(spi_device_t spi_device);

/* JEDEC */
void spi_device_jedec_cc_set(spi_device_t spi_device, uint8_t cc, uint8_t num_cc);
uint16_t spi_device_jedec_cc_get(spi_device_t spi_device);
void spi_device_jedec_id_set_raw(spi_device_t spi_device, uint32_t data);
void spi_device_jedec_id_set(spi_device_t spi_device, bool rom_bootstrap, uint8_t chip_rev,
                             uint8_t chip_gen, uint8_t density, uint8_t manufacturer_id);
uint32_t spi_device_jedec_id_get(spi_device_t spi_device);

/* mailbox */
void spi_device_mailbox_addr_set(spi_device_t spi_device, uint32_t addr);
uint32_t spi_device_mailbox_addr_get(spi_device_t spi_device);

/* upload */
uint32_t spi_device_upload_status_get(spi_device_t spi_device);
uint32_t spi_device_upload_status2_get(spi_device_t spi_device);
uint32_t spi_device_upload_cmdfifo_read(spi_device_t spi_device);
uint32_t spi_device_upload_addrfifo_read(spi_device_t spi_device);

/* cmd filter - idx is 0-based array index (0..7) */
void spi_device_cmd_filter_set(spi_device_t spi_device, uint8_t idx, uint32_t data);
uint32_t spi_device_cmd_filter_get(spi_device_t spi_device, uint8_t idx);

/* cmd info - idx is 0-based array index (0..23) */
void spi_device_cmd_info_set_raw(spi_device_t spi_device, uint8_t idx, uint32_t data);
void spi_device_cmd_info_set(spi_device_t spi_device, uint8_t idx, uint8_t opcode,
                             uint8_t addr_mode, uint8_t dummy_cycles, bool handled_in_sw);
uint32_t spi_device_cmd_info_get(spi_device_t spi_device, uint8_t idx);
void spi_device_cmd_info_4b_enable_set_raw(spi_device_t spi_device, uint32_t data);
void spi_device_cmd_info_4b_enable_set(spi_device_t spi_device, uint8_t opcode);
void spi_device_cmd_info_write_enable_set_raw(spi_device_t spi_device, uint32_t data);
void spi_device_cmd_info_write_enable_set(spi_device_t spi_device, uint8_t opcode);
uint32_t spi_device_cmd_info_write_enable_get(spi_device_t spi_device);
void spi_device_cmd_info_write_disable_set_raw(spi_device_t spi_device, uint32_t data);
void spi_device_cmd_info_write_disable_set(spi_device_t spi_device, uint8_t opcode);
uint32_t spi_device_cmd_info_write_disable_get(spi_device_t spi_device);

/* buffers */
bool spi_device_flash_read_buffer_write(spi_device_t spi_device, uint32_t offset, uint32_t data);
uint32_t spi_device_flash_payload_buffer_read(spi_device_t spi_device, uint32_t offset);

static inline uint64_t
spi_device_flash_payload_buffer_read64(spi_device_t spi_device, uint32_t offset)
{
    return *((volatile uint64_t *)&spi_device->ingress_buffer[offset / sizeof(uint32_t)]);
}

/* initialisation */
void spi_device_sfdp_table_init(spi_device_t spi_device);
void spi_device_init(spi_device_t spi_device);

/* command receive */
spi_device_cmd_t spi_device_cmd_get(spi_device_t spi_device);
spi_device_cmd_t spi_device_cmd_get_non_blocking(spi_device_t spi_device);
