// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include "hal/mmio.h"
#include <stdbool.h>
#include <stdint.h>

#define SPI_DEVICE_INTR_STATE_REG                (0x0)
#define SPI_DEVICE_INTR_ENABLE_REG               (0x4)
#define SPI_DEVICE_INTR_TEST_REG                 (0x8)
#define SPI_DEVICE_INTR_UPLOAD_CMDFIFO_NOT_EMPTY (0)
#define SPI_DEVICE_INTR_UPLOAD_PAYLOAD_NOT_EMPTY (1)
#define SPI_DEVICE_INTR_UPLOAD_PAYLOAD_OVERFLOW  (2)
#define SPI_DEVICE_INTR_READBUF_WATERMARK        (3)
#define SPI_DEVICE_INTR_READBUF_FLIP             (4)
#define SPI_DEVICE_INTR_TPM_HEADER_NOT_EMPTY     (5)
#define SPI_DEVICE_INTR_TPM_RDFIFO_CMD_END       (6)
#define SPI_DEVICE_INTR_TPM_RDFIFO_DROP          (7)
#define SPI_DEVICE_MAX_INTR                      (7)

#define SPI_DEVICE_ADDR_MODE_REG          (0x20)
#define SPI_DEVICE_ADDR_MODE_4B_EN_MASK   (0x1)
#define SPI_DEVICE_ADDR_MODE_PENDING_MASK (0x70000000)

#define SPI_DEVICE_FLASH_STATUS_REG       (0x28)
#define SPI_DEVICE_FLASH_STATUS_BUSY_MASK (0x1)
#define SPI_DEVICE_FLASH_STATUS_WEL_MASK  (0x2)

#define SPI_DEVICE_JEDEC_CC_REG (0x2C)
#define SPI_DEVICE_JEDEC_CC     (0)
#define SPI_DEVICE_JEDEC_NUM_CC (8)

#define SPI_DEVICE_JEDEC_ID_REG    (0x30)
#define SPI_DEVICE_CHIP_REV        (0)
#define SPI_DEVICE_CHIP_REV_MASK   (0x7)
#define SPI_DEVICE_ROM_BOOTSTRAP   (3)
#define SPI_DEVICE_CHIP_GEN        (4)
#define SPI_DEVICE_CHIP_GEN_MASK   (0xF)
#define SPI_DEVICE_DENSITY         (8)
#define SPI_DEVICE_MANUFACTURER_ID (16)

#define SPI_DEVICE_MAILBOX_ADDR_REG (0x38)

#define SPI_DEVICE_UPLOAD_STATUS_REG                    (0x3C)
#define SPI_DEVICE_UPLOAD_STATUS_CMDFIFO_NOTEMPTY_MASK  (0x80)
#define SPI_DEVICE_UPLOAD_STATUS_ADDRFIFO_NOTEMPTY_MASK (0x8000)

#define SPI_DEVICE_UPLOAD_STATUS2_REG                (0x40)
#define SPI_DEVICE_UPLOAD_STATUS2_PAYLOAD_DEPTH_MASK (0x1FF)

#define SPI_DEVICE_UPLOAD_CMDFIFO_REG  (0x44)
#define SPI_DEVICE_UPLOAD_ADDRFIFO_REG (0x48)

#define SPI_DEVICE_CMD_FILTER_0_REG (0x4C)
#define SPI_DEVICE_CMD_FILTER_1_REG (0x50)
#define SPI_DEVICE_CMD_FILTER_2_REG (0x54)
#define SPI_DEVICE_CMD_FILTER_3_REG (0x58)
#define SPI_DEVICE_CMD_FILTER_4_REG (0x5C)
#define SPI_DEVICE_CMD_FILTER_5_REG (0x60)
#define SPI_DEVICE_CMD_FILTER_6_REG (0x64)
#define SPI_DEVICE_CMD_FILTER_7_REG (0x68)

#define SPI_DEVICE_CMD_INFO_0_REG              (0x7C)
#define SPI_DEVICE_CMD_INFO_1_REG              (0x80)
#define SPI_DEVICE_CMD_INFO_2_REG              (0x84)
#define SPI_DEVICE_CMD_INFO_3_REG              (0x88)
#define SPI_DEVICE_CMD_INFO_4_REG              (0x8C)
#define SPI_DEVICE_CMD_INFO_5_REG              (0x90)
#define SPI_DEVICE_CMD_INFO_6_REG              (0x94)
#define SPI_DEVICE_CMD_INFO_7_REG              (0x98)
#define SPI_DEVICE_CMD_INFO_8_REG              (0x9C)
#define SPI_DEVICE_CMD_INFO_9_REG              (0xA0)
#define SPI_DEVICE_CMD_INFO_10_REG             (0xA4)
#define SPI_DEVICE_CMD_INFO_11_REG             (0xA8)
#define SPI_DEVICE_CMD_INFO_12_REG             (0xAC)
#define SPI_DEVICE_CMD_INFO_13_REG             (0xB0)
#define SPI_DEVICE_CMD_INFO_14_REG             (0xB4)
#define SPI_DEVICE_CMD_INFO_15_REG             (0xB8)
#define SPI_DEVICE_CMD_INFO_16_REG             (0xBC)
#define SPI_DEVICE_CMD_INFO_17_REG             (0xC0)
#define SPI_DEVICE_CMD_INFO_18_REG             (0xC4)
#define SPI_DEVICE_CMD_INFO_19_REG             (0xC8)
#define SPI_DEVICE_CMD_INFO_20_REG             (0xCC)
#define SPI_DEVICE_CMD_INFO_21_REG             (0xD0)
#define SPI_DEVICE_CMD_INFO_22_REG             (0xD4)
#define SPI_DEVICE_CMD_INFO_23_REG             (0xD8)
#define SPI_DEVICE_CMD_OPCODE                  (0)
#define SPI_DEVICE_CMD_ADDR_MODE               (8)
#define SPI_DEVICE_CMD_ADDR_MODE_MASK          (0x3)
#define SPI_DEVICE_CMD_ADDR_MODE_ADDR_DISABLED (0x0)
#define SPI_DEVICE_CMD_ADDR_MODE_ADDR_CFG      (0x1)
#define SPI_DEVICE_CMD_ADDR_MODE_ADDR_3B       (0x2)
#define SPI_DEVICE_CMD_ADDR_MODE_ADDR_4B       (0x3)
#define SPI_DEVICE_CMD_DUMMY_SIZE              (12)
#define SPI_DEVICE_CMD_DUMMY_SIZE_MASK         (0x7)
#define SPI_DEVICE_CMD_DUMMY_EN                (15)
#define SPI_DEVICE_CMD_UPLOAD                  (24)
#define SPI_DEVICE_CMD_BUSY                    (25)
#define SPI_DEVICE_CMD_VALID                   (31)

#define SPI_DEVICE_CMD_INFO_WREN_REG (0xE4)
#define SPI_DEVICE_CMD_INFO_WRDI_REG (0xE8)

#define SPI_DEVICE_EGRESS_BUFFER_OFFSET  (0x1000)
#define SPI_DEVICE_READ_BUFFER_OFFSET    (0x0)
#define SPI_DEVICE_READ_BUFFER_NUM_BYTES (2048)
#define SPI_DEVICE_SFDP_AREA_OFFSET      (0xC00)
#define SPI_DEVICE_SFDP_AREA_NUM_BYTES   (256)

#define SPI_DEVICE_INGRESS_BUFFER_OFFSET  (0x1E00)
#define SPI_DEVICE_PAYLOAD_AREA_OFFSET    (0x0)
#define SPI_DEVICE_PAYLOAD_AREA_NUM_BYTES (256)

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

#define SPI_DEVICE_OPCODE_PAGE_PROGRAM  (0x02)
#define SPI_DEVICE_OPCODE_READ_DATA     (0x03)
#define SPI_DEVICE_OPCODE_WRITE_DISABLE (0x04)
#define SPI_DEVICE_OPCODE_READ_STATUS   (0x05)
#define SPI_DEVICE_OPCODE_WRITE_ENABLE  (0x06)
#define SPI_DEVICE_OPCODE_SECTOR_ERASE  (0x20)
#define SPI_DEVICE_OPCODE_READ_SFDP     (0x5A)
#define SPI_DEVICE_OPCODE_RESET         (0x99)
#define SPI_DEVICE_OPCODE_READ_JEDEC_ID (0x9F)
#define SPI_DEVICE_OPCODE_CHIP_ERASE    (0xC7)

#define MOCHA_SPI_DEVICE_JEDEC_CC           (0x7F)
#define MOCHA_SPI_DEVICE_JEDEC_CC_COUNT     (0)
#define MOCHA_SPI_DEVICE_ROM_BOOTSTRAP      (true)
#define MOCHA_SPI_DEVICE_CHIP_REV           (0)
#define MOCHA_SPI_DEVICE_CHIP_GEN           (0)
#define MOCHA_SPI_DEVICE_DENSITY_BITS       ((1 << 20) * 8)
#define MOCHA_SPI_DEVICE_DENSITY_BYTES_LOG2 (20)
#define MOCHA_SPI_DEVICE_MANUFACTURER_ID    (0xef)

typedef void *spi_device_t;

typedef struct spi_device_cmd {
    uint8_t status;
    uint8_t opcode;
    uint16_t payload_byte_count;
    uint32_t address;
} spi_device_cmd_t;

bool spi_device_interrupt_is_pending(spi_device_t spi_device, uint8_t intr_id);
void spi_device_interrupt_clear(spi_device_t spi_device, uint8_t intr_id);
void spi_device_interrupt_disable_all(spi_device_t spi_device);
void spi_device_interrupt_enable(spi_device_t spi_device, uint8_t intr_id);
void spi_device_interrupt_disable(spi_device_t spi_device, uint8_t intr_id);
void spi_device_interrupt_trigger(spi_device_t spi_device, uint8_t intr_id);
void spi_device_4b_addr_mode_enable_set(spi_device_t spi_device, bool enable);
bool spi_device_4b_addr_mode_enable_get(spi_device_t spi_device);
void spi_device_flash_status_set(spi_device_t spi_device, uint32_t flash_status);
uint32_t spi_device_flash_status_get(spi_device_t spi_device);
void spi_device_jedec_cc_set(spi_device_t spi_device, uint8_t cc, uint8_t num_cc);
uint16_t spi_device_jedec_cc_get(spi_device_t spi_device);
void spi_device_jedec_id_set_raw(spi_device_t spi_device, uint32_t data);
void spi_device_jedec_id_set(spi_device_t spi_device, bool rom_bootstrap, uint8_t chip_rev,
                             uint8_t chip_gen, uint8_t density, uint8_t manufacturer_id);
uint32_t spi_device_jedec_id_get(spi_device_t spi_device);
void spi_device_mailbox_addr_set(spi_device_t spi_device, uint32_t addr);
uint32_t spi_device_mailbox_addr_get(spi_device_t spi_device);
uint32_t spi_device_upload_status_get(spi_device_t spi_device);
uint32_t spi_device_upload_status2_get(spi_device_t spi_device);
uint32_t spi_device_upload_cmdfifo_read(spi_device_t spi_device);
uint32_t spi_device_upload_addrfifo_read(spi_device_t spi_device);
void spi_device_cmd_filter_set(spi_device_t spi_device, uint32_t offset, uint32_t data);
uint32_t spi_device_cmd_filter_get(spi_device_t spi_device, uint32_t offset);
void spi_device_cmd_info_set_raw(spi_device_t spi_device, uint32_t offset, uint32_t data);
void spi_device_cmd_info_set(spi_device_t spi_device, uint32_t offset, uint8_t opcode, bool address,
                             uint8_t dummy_cycles, bool handled_in_sw);
uint32_t spi_device_cmd_info_get(spi_device_t spi_device, uint32_t offset);
void spi_device_cmd_info_write_enable_set_raw(spi_device_t spi_device, uint32_t data);
void spi_device_cmd_info_write_enable_set(spi_device_t spi_device, uint8_t opcode);
uint32_t spi_device_cmd_info_write_enable_get(spi_device_t spi_device);
void spi_device_cmd_info_write_disable_set_raw(spi_device_t spi_device, uint32_t data);
void spi_device_cmd_info_write_disable_set(spi_device_t spi_device, uint8_t opcode);
uint32_t spi_device_cmd_info_write_disable_get(spi_device_t spi_device);
bool spi_device_flash_read_buffer_write(spi_device_t spi_device, uint32_t offset, uint32_t data);
uint32_t spi_device_flash_payload_buffer_read(spi_device_t spi_device, uint32_t offset);

static inline uint64_t
spi_device_flash_payload_buffer_read64(spi_device_t spi_device, uint32_t offset)
{
    uintptr_t addr = (uint64_t)spi_device + SPI_DEVICE_INGRESS_BUFFER_OFFSET +
                     SPI_DEVICE_PAYLOAD_AREA_OFFSET + offset;
    return DEV_READ64(addr);
}

void spi_device_sfdp_table_init(spi_device_t spi_device);
void spi_device_init(spi_device_t spi_device);
spi_device_cmd_t spi_device_cmd_get(spi_device_t spi_device);
