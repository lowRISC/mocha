// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include "autogen/spi_device.h"
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

enum spi_device_flash_mode : uint32_t {
    spi_device_flash_mode_disabled = 0x0u,
    spi_device_flash_mode_flash = 0x1u,
    spi_device_flash_mode_passthrough = 0x2u,
};

enum spi_device_addr_mode : uint32_t {
    spi_device_addr_mode_disabled = 0x0u,
    spi_device_addr_mode_cfg = 0x1u,
    spi_device_addr_mode_3b = 0x2u,
    spi_device_addr_mode_4b = 0x3u,
};

enum spi_device_opcode : uint8_t {
    spi_device_opcode_page_program = 0x02u,
    spi_device_opcode_read = 0x03u,
    spi_device_opcode_wrdi = 0x04u,
    spi_device_opcode_read_status = 0x05u,
    spi_device_opcode_wren = 0x06u,
    spi_device_opcode_page_program_4b = 0x12u,
    spi_device_opcode_sector_erase = 0x20u,
    spi_device_opcode_sector_erase_4b = 0x21u,
    spi_device_opcode_read_sfdp = 0x5au,
    spi_device_opcode_reset = 0x99u,
    spi_device_opcode_read_jedec = 0x9fu,
    spi_device_opcode_chip_erase = 0xc7u,
};

enum spi_device_egress_buffer_size : size_t {
    spi_device_egress_buffer_size_read = 512u,
    spi_device_egress_buffer_size_mailbox = 256u,
    spi_device_egress_buffer_size_sfdp = 64u,
    spi_device_egress_buffer_size_tpm_read_fifo = 16u,
};

_Static_assert((spi_device_egress_buffer_size_read + spi_device_egress_buffer_size_mailbox +
                spi_device_egress_buffer_size_sfdp + spi_device_egress_buffer_size_tpm_read_fifo) ==
                   sizeof(((spi_device_t)0)->egress_buffer) / sizeof(uint32_t),
               "incorrect spi_device egress_buffer sizes");

enum spi_device_egress_buffer_offset : size_t {
    spi_device_egress_buffer_offset_read = 0u,
    spi_device_egress_buffer_offset_mailbox =
        spi_device_egress_buffer_offset_read + spi_device_egress_buffer_size_read,
    spi_device_egress_buffer_offset_sfdp =
        spi_device_egress_buffer_offset_mailbox + spi_device_egress_buffer_size_mailbox,
    spi_device_egress_buffer_offset_tpm_read_fifo =
        spi_device_egress_buffer_offset_sfdp + spi_device_egress_buffer_size_sfdp,
};

_Static_assert(spi_device_egress_buffer_offset_read == 0ul,
               "incorrect spi_device egress_buffer read offset");
_Static_assert(spi_device_egress_buffer_offset_mailbox == 512ul,
               "incorrect spi_device egress_buffer mailbox offset");
_Static_assert(spi_device_egress_buffer_offset_sfdp == 768ul,
               "incorrect spi_device egress_buffer sfdp offset");
_Static_assert(spi_device_egress_buffer_offset_tpm_read_fifo == 832ul,
               "incorrect spi_device egress_buffer tpm_read_fifo offset");

enum spi_device_ingress_buffer_size : size_t {
    spi_device_ingress_buffer_size_payload_fifo = 64u,
    spi_device_ingress_buffer_size_cmd_fifo = 16u,
    spi_device_ingress_buffer_size_addr_fifo = 16u,
    spi_device_ingress_buffer_size_tpm_write_fifo = 16u,
};

_Static_assert((spi_device_ingress_buffer_size_payload_fifo +
                spi_device_ingress_buffer_size_cmd_fifo + spi_device_ingress_buffer_size_addr_fifo +
                spi_device_ingress_buffer_size_tpm_write_fifo) ==
                   sizeof(((spi_device_t)0)->ingress_buffer) / sizeof(uint32_t),
               "incorrect spi_device ingress_buffer sizes");

enum spi_device_ingress_buffer_offset : size_t {
    spi_device_ingress_buffer_offset_payload_fifo = 0u,
    spi_device_ingress_buffer_offset_cmd_fifo =
        spi_device_ingress_buffer_offset_payload_fifo + spi_device_ingress_buffer_size_payload_fifo,
    spi_device_ingress_buffer_offset_addr_fifo =
        spi_device_ingress_buffer_offset_cmd_fifo + spi_device_ingress_buffer_size_cmd_fifo,
    spi_device_ingress_buffer_offset_tpm_write_fifo =
        spi_device_ingress_buffer_offset_addr_fifo + spi_device_ingress_buffer_size_addr_fifo,
};

_Static_assert(spi_device_ingress_buffer_offset_payload_fifo == 0ul,
               "incorrect spi_device ingress_buffer payload_fifo offset");
_Static_assert(spi_device_ingress_buffer_offset_cmd_fifo == 64ul,
               "incorrect spi_device ingress_buffer cmd_fifo offset");
_Static_assert(spi_device_ingress_buffer_offset_addr_fifo == 80ul,
               "incorrect spi_device ingress_buffer addr_fifo offset");
_Static_assert(spi_device_ingress_buffer_offset_tpm_write_fifo == 96ul,
               "incorrect spi_device ingress_buffer tpm_read_fifo offset");

enum spi_device_status {
    spi_device_status_ready = 0u,
    spi_device_status_empty = 1u,
    spi_device_status_overflow = 2u,
};

typedef struct {
    bool has_address;
    uint8_t opcode;
    uint16_t payload_byte_count;
    uint32_t address;
} spi_device_software_command;

/* initialisation */
void spi_device_init(spi_device_t spi_device);
void spi_device_flash_mode_set(spi_device_t spi_device, enum spi_device_flash_mode mode);

/* interrupts */
spi_device_intr spi_device_interrupt_enable_get(spi_device_t spi_device);
void spi_device_interrupt_enable_set(spi_device_t spi_device, spi_device_intr intrs);
void spi_device_interrupt_enable(spi_device_t spi_device, spi_device_intr intrs);
void spi_device_interrupt_disable(spi_device_t spi_device, spi_device_intr intrs);
void spi_device_interrupt_disable_all(spi_device_t spi_device);
void spi_device_interrupt_force(spi_device_t spi_device, spi_device_intr intrs);
void spi_device_interrupt_clear(spi_device_t spi_device, spi_device_intr intrs);
bool spi_device_interrupt_all_pending(spi_device_t spi_device, spi_device_intr intrs);
bool spi_device_interrupt_any_pending(spi_device_t spi_device, spi_device_intr intrs);

/* SPI device flash status */
spi_device_flash_status spi_device_flash_status_get(spi_device_t spi_device);
void spi_device_flash_status_set(spi_device_t spi_device, spi_device_flash_status status);
void spi_device_flash_status_busy_set(spi_device_t spi_device, bool busy);
void spi_device_flash_status_wel_set(spi_device_t spi_device, bool wel);

/* SPI device command info and address mode */
bool spi_device_4b_addr_mode_enable_get(spi_device_t spi_device);
void spi_device_4b_addr_mode_enable_set(spi_device_t spi_device, bool enable);
void spi_device_4b_addr_mode_enable_set_unchecked(spi_device_t spi_device, bool enable);
spi_device_cmd_info spi_device_cmd_info_get(spi_device_t spi_device, size_t index);
void spi_device_cmd_info_set(spi_device_t spi_device, spi_device_cmd_info cmd_info, size_t index);
spi_device_cmd_info_wren spi_device_cmd_info_wren_get(spi_device_t spi_device);
void spi_device_cmd_info_wren_set(spi_device_t spi_device, uint8_t opcode, bool valid);
spi_device_cmd_info_wrdi spi_device_cmd_info_wrdi_get(spi_device_t spi_device);
void spi_device_cmd_info_wrdi_set(spi_device_t spi_device, uint8_t opcode, bool valid);

/* SPI device command filtering */
uint32_t spi_device_cmd_filter_get(spi_device_t spi_device, size_t index);
void spi_device_cmd_filter_enable_all(spi_device_t spi_device);
void spi_device_cmd_filter_enable_set(spi_device_t spi_device, size_t index, uint32_t filter);
void spi_device_cmd_filter_enable(spi_device_t spi_device, size_t index, uint32_t filter);
void spi_device_cmd_filter_disable(spi_device_t spi_device, size_t index, uint32_t filter);
void spi_device_cmd_filter_disable_all(spi_device_t spi_device);

/* SPI device JEDEC configuration */
spi_device_jedec_cc spi_device_jedec_cc_get(spi_device_t spi_device);
void spi_device_jedec_cc_set(spi_device_t spi_device, spi_device_jedec_cc jedec_cc);
spi_device_jedec_id spi_device_jedec_id_get(spi_device_t spi_device);
void spi_device_jedec_id_set(spi_device_t spi_device, spi_device_jedec_id jedec_id);

/* SPI device sw-handled command FIFOs and mailbox */
spi_device_upload_status spi_device_upload_status_get(spi_device_t spi_device);
spi_device_upload_status2 spi_device_upload_status2_get(spi_device_t spi_device);
spi_device_upload_cmdfifo spi_device_upload_cmdfifo_get(spi_device_t spi_device);
uint32_t spi_device_upload_addrfifo_get(spi_device_t spi_device);
uint32_t spi_device_mailbox_addr_get(spi_device_t spi_device);
void spi_device_mailbox_addr_set(spi_device_t spi_device, uint32_t mailbox_addr);

/* SPI device uploaded sw-handled command */
enum spi_device_status
spi_device_software_command_get(spi_device_t spi_device, spi_device_software_command *command);
enum spi_device_status spi_device_software_command_get_non_blocking(
    spi_device_t spi_device, spi_device_software_command *command);

/* SPI device flash payload buffer */
void spi_device_flash_payload_buffer_copy_bytes(spi_device_t spi_device, size_t num_bytes,
                                                uint32_t *dest);
bool spi_device_flash_payload_buffer_read_word(spi_device_t spi_device, size_t word_index,
                                               uint32_t *word);
bool spi_device_flash_payload_buffer_read_byte(spi_device_t spi_device, size_t byte_index,
                                               uint8_t *byte);

/* SPI device flash read buffer */
bool spi_device_flash_read_buffer_write_word(spi_device_t spi_device, size_t word_index,
                                             uint32_t word);
bool spi_device_flash_read_buffer_write_byte(spi_device_t spi_device, size_t byte_index,
                                             uint8_t byte);
