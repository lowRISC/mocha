// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Auto-generated: 'util/rdlgenerator.py gen-device-headers build/rdl/rdl.json sw/device/lib/hal/autogen'

#pragma once

#include <stdbool.h>
#include <stdint.h>

typedef enum [[clang::flag_enum]] spi_device_intr : uint32_t {
    spi_device_intr_upload_cmdfifo_not_empty = (1u << 0),
    spi_device_intr_upload_payload_not_empty = (1u << 1),
    spi_device_intr_upload_payload_overflow = (1u << 2),
    spi_device_intr_readbuf_watermark = (1u << 3),
    spi_device_intr_readbuf_flip = (1u << 4),
    spi_device_intr_tpm_header_not_empty = (1u << 5),
    spi_device_intr_tpm_rdfifo_cmd_end = (1u << 6),
    spi_device_intr_tpm_rdfifo_drop = (1u << 7),
} spi_device_intr;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fatal_fault : 1;
    uint32_t : 31;
} spi_device_alert_test;

typedef struct [[gnu::aligned(4)]] {
    uint32_t flash_status_fifo_clr : 1;
    uint32_t flash_read_buffer_clr : 1;
    uint32_t : 2;
    uint32_t mode : 2;
    uint32_t : 26;
} spi_device_control;

typedef struct [[gnu::aligned(4)]] {
    uint32_t : 1;
    uint32_t tx_order : 1;
    uint32_t rx_order : 1;
    uint32_t : 20;
    uint32_t mailbox_en : 1;
    uint32_t : 7;
} spi_device_cfg;

typedef struct [[gnu::aligned(4)]] {
    uint32_t : 4;
    uint32_t csb : 1;
    uint32_t tpm_csb : 1;
    uint32_t : 25;
} spi_device_status;

typedef enum [[clang::flag_enum]] spi_device_intercept_en : uint32_t {
    spi_device_intercept_en_status = (1u << 0),
    spi_device_intercept_en_jedec = (1u << 1),
    spi_device_intercept_en_sfdp = (1u << 2),
    spi_device_intercept_en_mbx = (1u << 3),
} spi_device_intercept_en;

typedef struct [[gnu::aligned(4)]] {
    uint32_t addr_4b_en : 1;
    uint32_t : 30;
    uint32_t pending : 1;
} spi_device_addr_mode;

typedef struct [[gnu::aligned(4)]] {
    uint32_t busy : 1;
    uint32_t wel : 1;
    uint32_t status : 22;
    uint32_t : 8;
} spi_device_flash_status;

typedef struct [[gnu::aligned(4)]] {
    uint32_t cc : 8;
    uint32_t num_cc : 8;
    uint32_t : 16;
} spi_device_jedec_cc;

typedef struct [[gnu::aligned(4)]] {
    uint32_t id : 16;
    uint32_t mf : 8;
    uint32_t : 8;
} spi_device_jedec_id;

typedef struct [[gnu::aligned(4)]] {
    uint32_t threshold : 10;
    uint32_t : 22;
} spi_device_read_threshold;

typedef struct [[gnu::aligned(4)]] {
    uint32_t cmdfifo_depth : 5;
    uint32_t : 2;
    uint32_t cmdfifo_notempty : 1;
    uint32_t addrfifo_depth : 5;
    uint32_t : 2;
    uint32_t addrfifo_notempty : 1;
    uint32_t : 16;
} spi_device_upload_status;

typedef struct [[gnu::aligned(4)]] {
    uint32_t payload_depth : 9;
    uint32_t : 7;
    uint32_t payload_start_idx : 8;
    uint32_t : 8;
} spi_device_upload_status2;

typedef struct [[gnu::aligned(4)]] {
    uint32_t data : 8;
    uint32_t : 5;
    uint32_t busy : 1;
    uint32_t wel : 1;
    uint32_t addr4b_mode : 1;
    uint32_t : 16;
} spi_device_upload_cmdfifo;

typedef struct [[gnu::aligned(4)]] {
    uint32_t opcode : 8;
    uint32_t addr_mode : 2;
    uint32_t addr_swap_en : 1;
    uint32_t mbyte_en : 1;
    uint32_t dummy_size : 3;
    uint32_t dummy_en : 1;
    uint32_t payload_en : 4;
    uint32_t payload_dir : 1;
    uint32_t payload_swap_en : 1;
    uint32_t read_pipeline_mode : 2;
    uint32_t upload : 1;
    uint32_t busy : 1;
    uint32_t : 5;
    uint32_t valid : 1;
} spi_device_cmd_info;

typedef struct [[gnu::aligned(4)]] {
    uint32_t opcode : 8;
    uint32_t : 23;
    uint32_t valid : 1;
} spi_device_cmd_info_en4b;

typedef struct [[gnu::aligned(4)]] {
    uint32_t opcode : 8;
    uint32_t : 23;
    uint32_t valid : 1;
} spi_device_cmd_info_ex4b;

typedef struct [[gnu::aligned(4)]] {
    uint32_t opcode : 8;
    uint32_t : 23;
    uint32_t valid : 1;
} spi_device_cmd_info_wren;

typedef struct [[gnu::aligned(4)]] {
    uint32_t opcode : 8;
    uint32_t : 23;
    uint32_t valid : 1;
} spi_device_cmd_info_wrdi;

typedef struct [[gnu::aligned(4)]] {
    uint32_t rev : 8;
    uint32_t locality : 1;
    uint32_t : 7;
    uint32_t max_wr_size : 3;
    uint32_t : 1;
    uint32_t max_rd_size : 3;
    uint32_t : 9;
} spi_device_tpm_cap;

typedef enum [[clang::flag_enum]] spi_device_tpm_cfg : uint32_t {
    spi_device_tpm_cfg_en = (1u << 0),
    spi_device_tpm_cfg_tpm_mode = (1u << 1),
    spi_device_tpm_cfg_hw_reg_dis = (1u << 2),
    spi_device_tpm_cfg_tpm_reg_chk_dis = (1u << 3),
    spi_device_tpm_cfg_invalid_locality = (1u << 4),
} spi_device_tpm_cfg;

typedef enum [[clang::flag_enum]] spi_device_tpm_status : uint32_t {
    spi_device_tpm_status_cmdaddr_notempty = (1u << 0),
    spi_device_tpm_status_wrfifo_pending = (1u << 1),
    spi_device_tpm_status_rdfifo_aborted = (1u << 2),
} spi_device_tpm_status;

typedef struct [[gnu::aligned(4)]] {
    uint32_t access_0 : 8;
    uint32_t access_1 : 8;
    uint32_t access_2 : 8;
    uint32_t access_3 : 8;
} spi_device_tpm_access_0;

typedef struct [[gnu::aligned(4)]] {
    uint32_t access_4 : 8;
    uint32_t : 24;
} spi_device_tpm_access_1;

typedef struct [[gnu::aligned(4)]] {
    uint32_t int_vector : 8;
    uint32_t : 24;
} spi_device_tpm_int_vector;

typedef struct [[gnu::aligned(4)]] {
    uint32_t vid : 16;
    uint32_t did : 16;
} spi_device_tpm_did_vid;

typedef struct [[gnu::aligned(4)]] {
    uint32_t rid : 8;
    uint32_t : 24;
} spi_device_tpm_rid;

typedef struct [[gnu::aligned(4)]] {
    uint32_t addr : 24;
    uint32_t cmd : 8;
} spi_device_tpm_cmd_addr;

typedef volatile struct [[gnu::aligned(4)]] spi_device_memory_layout {
    /* spi_device.intr_state (0x0) */
    spi_device_intr intr_state;

    /* spi_device.intr_enable (0x4) */
    spi_device_intr intr_enable;

    /* spi_device.intr_test (0x8) */
    spi_device_intr intr_test;

    /* spi_device.alert_test (0xc) */
    spi_device_alert_test alert_test;

    /* spi_device.control (0x10) */
    spi_device_control control;

    /* spi_device.cfg (0x14) */
    spi_device_cfg cfg;

    /* spi_device.status (0x18) */
    const spi_device_status status;

    /* spi_device.intercept_en (0x1c) */
    spi_device_intercept_en intercept_en;

    /* spi_device.addr_mode (0x20) */
    spi_device_addr_mode addr_mode;

    /* spi_device.last_read_addr (0x24) */
    const uint32_t last_read_addr;

    /* spi_device.flash_status (0x28) */
    spi_device_flash_status flash_status;

    /* spi_device.jedec_cc (0x2c) */
    spi_device_jedec_cc jedec_cc;

    /* spi_device.jedec_id (0x30) */
    spi_device_jedec_id jedec_id;

    /* spi_device.read_threshold (0x34) */
    spi_device_read_threshold read_threshold;

    /* spi_device.mailbox_addr (0x38) */
    uint32_t mailbox_addr;

    /* spi_device.upload_status (0x3c) */
    const spi_device_upload_status upload_status;

    /* spi_device.upload_status2 (0x40) */
    const spi_device_upload_status2 upload_status2;

    /* spi_device.upload_cmdfifo (0x44) */
    const spi_device_upload_cmdfifo upload_cmdfifo;

    /* spi_device.upload_addrfifo (0x48) */
    const uint32_t upload_addrfifo;

    /* spi_device.cmd_filter (0x4c-0x68) */
    uint32_t cmd_filter[8];

    /* spi_device.addr_swap_mask (0x6c) */
    uint32_t addr_swap_mask;

    /* spi_device.addr_swap_data (0x70) */
    uint32_t addr_swap_data;

    /* spi_device.payload_swap_mask (0x74) */
    uint32_t payload_swap_mask;

    /* spi_device.payload_swap_data (0x78) */
    uint32_t payload_swap_data;

    /* spi_device.cmd_info (0x7c-0xd8) */
    spi_device_cmd_info cmd_info[24];

    /* spi_device.cmd_info_en4b (0xdc) */
    spi_device_cmd_info_en4b cmd_info_en4b;

    /* spi_device.cmd_info_ex4b (0xe0) */
    spi_device_cmd_info_ex4b cmd_info_ex4b;

    /* spi_device.cmd_info_wren (0xe4) */
    spi_device_cmd_info_wren cmd_info_wren;

    /* spi_device.cmd_info_wrdi (0xe8) */
    spi_device_cmd_info_wrdi cmd_info_wrdi;

    const uint8_t __reserved0[0x800 - 0xec];

    /* spi_device.tpm_cap (0x800) */
    const spi_device_tpm_cap tpm_cap;

    /* spi_device.tpm_cfg (0x804) */
    spi_device_tpm_cfg tpm_cfg;

    /* spi_device.tpm_status (0x808) */
    spi_device_tpm_status tpm_status;

    /* spi_device.tpm_access_0 (0x80c) */
    spi_device_tpm_access_0 tpm_access_0;

    /* spi_device.tpm_access_1 (0x810) */
    spi_device_tpm_access_1 tpm_access_1;

    /* spi_device.tpm_sts (0x814) */
    uint32_t tpm_sts;

    /* spi_device.tpm_intf_capability (0x818) */
    uint32_t tpm_intf_capability;

    /* spi_device.tpm_int_enable (0x81c) */
    uint32_t tpm_int_enable;

    /* spi_device.tpm_int_vector (0x820) */
    spi_device_tpm_int_vector tpm_int_vector;

    /* spi_device.tpm_int_status (0x824) */
    uint32_t tpm_int_status;

    /* spi_device.tpm_did_vid (0x828) */
    spi_device_tpm_did_vid tpm_did_vid;

    /* spi_device.tpm_rid (0x82c) */
    spi_device_tpm_rid tpm_rid;

    /* spi_device.tpm_cmd_addr (0x830) */
    const spi_device_tpm_cmd_addr tpm_cmd_addr;

    /* spi_device.tpm_read_fifo (0x834) */
    uint32_t tpm_read_fifo;

    const uint8_t __reserved1[0x1000 - 0x838];

    /* spi_device.egress_buffer (0x1000-0x1d3c) */
    uint32_t egress_buffer[848];

    const uint8_t __reserved2[0x1e00 - 0x1d40];

    /* spi_device.ingress_buffer (0x1e00-0x1fbc) */
    const uint32_t ingress_buffer[112];
} *spi_device_t;

_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, intr_state) == 0x0ul,
               "incorrect register intr_state offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, intr_enable) == 0x4ul,
               "incorrect register intr_enable offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, intr_test) == 0x8ul,
               "incorrect register intr_test offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, alert_test) == 0xcul,
               "incorrect register alert_test offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, control) == 0x10ul,
               "incorrect register control offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, cfg) == 0x14ul,
               "incorrect register cfg offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, status) == 0x18ul,
               "incorrect register status offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, intercept_en) == 0x1cul,
               "incorrect register intercept_en offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, addr_mode) == 0x20ul,
               "incorrect register addr_mode offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, last_read_addr) == 0x24ul,
               "incorrect register last_read_addr offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, flash_status) == 0x28ul,
               "incorrect register flash_status offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, jedec_cc) == 0x2cul,
               "incorrect register jedec_cc offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, jedec_id) == 0x30ul,
               "incorrect register jedec_id offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, read_threshold) == 0x34ul,
               "incorrect register read_threshold offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, mailbox_addr) == 0x38ul,
               "incorrect register mailbox_addr offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, upload_status) == 0x3cul,
               "incorrect register upload_status offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, upload_status2) == 0x40ul,
               "incorrect register upload_status2 offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, upload_cmdfifo) == 0x44ul,
               "incorrect register upload_cmdfifo offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, upload_addrfifo) == 0x48ul,
               "incorrect register upload_addrfifo offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, cmd_filter) == 0x4cul,
               "incorrect register cmd_filter offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, addr_swap_mask) == 0x6cul,
               "incorrect register addr_swap_mask offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, addr_swap_data) == 0x70ul,
               "incorrect register addr_swap_data offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, payload_swap_mask) == 0x74ul,
               "incorrect register payload_swap_mask offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, payload_swap_data) == 0x78ul,
               "incorrect register payload_swap_data offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, cmd_info) == 0x7cul,
               "incorrect register cmd_info offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, cmd_info_en4b) == 0xdcul,
               "incorrect register cmd_info_en4b offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, cmd_info_ex4b) == 0xe0ul,
               "incorrect register cmd_info_ex4b offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, cmd_info_wren) == 0xe4ul,
               "incorrect register cmd_info_wren offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, cmd_info_wrdi) == 0xe8ul,
               "incorrect register cmd_info_wrdi offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, tpm_cap) == 0x800ul,
               "incorrect register tpm_cap offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, tpm_cfg) == 0x804ul,
               "incorrect register tpm_cfg offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, tpm_status) == 0x808ul,
               "incorrect register tpm_status offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, tpm_access_0) == 0x80cul,
               "incorrect register tpm_access_0 offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, tpm_access_1) == 0x810ul,
               "incorrect register tpm_access_1 offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, tpm_sts) == 0x814ul,
               "incorrect register tpm_sts offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, tpm_intf_capability) == 0x818ul,
               "incorrect register tpm_intf_capability offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, tpm_int_enable) == 0x81cul,
               "incorrect register tpm_int_enable offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, tpm_int_vector) == 0x820ul,
               "incorrect register tpm_int_vector offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, tpm_int_status) == 0x824ul,
               "incorrect register tpm_int_status offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, tpm_did_vid) == 0x828ul,
               "incorrect register tpm_did_vid offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, tpm_rid) == 0x82cul,
               "incorrect register tpm_rid offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, tpm_cmd_addr) == 0x830ul,
               "incorrect register tpm_cmd_addr offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, tpm_read_fifo) == 0x834ul,
               "incorrect register tpm_read_fifo offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, egress_buffer) == 0x1000ul,
               "incorrect register window egress_buffer offset");
_Static_assert(__builtin_offsetof(struct spi_device_memory_layout, ingress_buffer) == 0x1e00ul,
               "incorrect register window ingress_buffer offset");

_Static_assert(sizeof(spi_device_intr) == sizeof(uint32_t),
               "register type spi_device_intr is not register sized");
_Static_assert(sizeof(spi_device_alert_test) == sizeof(uint32_t),
               "register type spi_device_alert_test is not register sized");
_Static_assert(sizeof(spi_device_control) == sizeof(uint32_t),
               "register type spi_device_control is not register sized");
_Static_assert(sizeof(spi_device_cfg) == sizeof(uint32_t),
               "register type spi_device_cfg is not register sized");
_Static_assert(sizeof(spi_device_status) == sizeof(uint32_t),
               "register type spi_device_status is not register sized");
_Static_assert(sizeof(spi_device_intercept_en) == sizeof(uint32_t),
               "register type spi_device_intercept_en is not register sized");
_Static_assert(sizeof(spi_device_addr_mode) == sizeof(uint32_t),
               "register type spi_device_addr_mode is not register sized");
_Static_assert(sizeof(spi_device_flash_status) == sizeof(uint32_t),
               "register type spi_device_flash_status is not register sized");
_Static_assert(sizeof(spi_device_jedec_cc) == sizeof(uint32_t),
               "register type spi_device_jedec_cc is not register sized");
_Static_assert(sizeof(spi_device_jedec_id) == sizeof(uint32_t),
               "register type spi_device_jedec_id is not register sized");
_Static_assert(sizeof(spi_device_read_threshold) == sizeof(uint32_t),
               "register type spi_device_read_threshold is not register sized");
_Static_assert(sizeof(spi_device_upload_status) == sizeof(uint32_t),
               "register type spi_device_upload_status is not register sized");
_Static_assert(sizeof(spi_device_upload_status2) == sizeof(uint32_t),
               "register type spi_device_upload_status2 is not register sized");
_Static_assert(sizeof(spi_device_upload_cmdfifo) == sizeof(uint32_t),
               "register type spi_device_upload_cmdfifo is not register sized");
_Static_assert(sizeof(spi_device_cmd_info) == sizeof(uint32_t),
               "register type spi_device_cmd_info is not register sized");
_Static_assert(sizeof(spi_device_cmd_info_en4b) == sizeof(uint32_t),
               "register type spi_device_cmd_info_en4b is not register sized");
_Static_assert(sizeof(spi_device_cmd_info_ex4b) == sizeof(uint32_t),
               "register type spi_device_cmd_info_ex4b is not register sized");
_Static_assert(sizeof(spi_device_cmd_info_wren) == sizeof(uint32_t),
               "register type spi_device_cmd_info_wren is not register sized");
_Static_assert(sizeof(spi_device_cmd_info_wrdi) == sizeof(uint32_t),
               "register type spi_device_cmd_info_wrdi is not register sized");
_Static_assert(sizeof(spi_device_tpm_cap) == sizeof(uint32_t),
               "register type spi_device_tpm_cap is not register sized");
_Static_assert(sizeof(spi_device_tpm_cfg) == sizeof(uint32_t),
               "register type spi_device_tpm_cfg is not register sized");
_Static_assert(sizeof(spi_device_tpm_status) == sizeof(uint32_t),
               "register type spi_device_tpm_status is not register sized");
_Static_assert(sizeof(spi_device_tpm_access_0) == sizeof(uint32_t),
               "register type spi_device_tpm_access_0 is not register sized");
_Static_assert(sizeof(spi_device_tpm_access_1) == sizeof(uint32_t),
               "register type spi_device_tpm_access_1 is not register sized");
_Static_assert(sizeof(spi_device_tpm_int_vector) == sizeof(uint32_t),
               "register type spi_device_tpm_int_vector is not register sized");
_Static_assert(sizeof(spi_device_tpm_did_vid) == sizeof(uint32_t),
               "register type spi_device_tpm_did_vid is not register sized");
_Static_assert(sizeof(spi_device_tpm_rid) == sizeof(uint32_t),
               "register type spi_device_tpm_rid is not register sized");
_Static_assert(sizeof(spi_device_tpm_cmd_addr) == sizeof(uint32_t),
               "register type spi_device_tpm_cmd_addr is not register sized");
