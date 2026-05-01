// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Auto-generated: 'util/rdlgenerator.py gen-device-headers build/rdl/rdl.json sw/device/lib/hal/autogen'

#pragma once

#include <stdbool.h>
#include <stdint.h>

typedef enum [[clang::flag_enum]] spi_host_intr : uint32_t {
    spi_host_intr_error = (1u << 0),
    spi_host_intr_spi_event = (1u << 1),
} spi_host_intr;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fatal_fault : 1;
    uint32_t : 31;
} spi_host_alert_test;

typedef struct [[gnu::aligned(4)]] {
    uint32_t rx_watermark : 8;
    uint32_t tx_watermark : 8;
    uint32_t : 13;
    uint32_t output_en : 1;
    uint32_t sw_rst : 1;
    uint32_t spien : 1;
} spi_host_control;

typedef struct [[gnu::aligned(4)]] {
    uint32_t txqd : 8;
    uint32_t rxqd : 8;
    uint32_t cmdqd : 4;
    uint32_t rxwm : 1;
    uint32_t : 1;
    uint32_t byteorder : 1;
    uint32_t rxstall : 1;
    uint32_t rxempty : 1;
    uint32_t rxfull : 1;
    uint32_t txwm : 1;
    uint32_t txstall : 1;
    uint32_t txempty : 1;
    uint32_t txfull : 1;
    uint32_t active : 1;
    uint32_t ready : 1;
} spi_host_status;

typedef struct [[gnu::aligned(4)]] {
    uint32_t clkdiv : 16;
    uint32_t csnidle : 4;
    uint32_t csntrail : 4;
    uint32_t csnlead : 4;
    uint32_t : 1;
    uint32_t fullcyc : 1;
    uint32_t cpha : 1;
    uint32_t cpol : 1;
} spi_host_configopts;

typedef struct [[gnu::aligned(4)]] {
    uint32_t csaat : 1;
    uint32_t speed : 2;
    uint32_t direction : 2;
    uint32_t len : 20;
    uint32_t : 7;
} spi_host_command;

typedef enum [[clang::flag_enum]] spi_host_error_enable : uint32_t {
    spi_host_error_enable_cmdbusy = (1u << 0),
    spi_host_error_enable_overflow = (1u << 1),
    spi_host_error_enable_underflow = (1u << 2),
    spi_host_error_enable_cmdinval = (1u << 3),
    spi_host_error_enable_csidinval = (1u << 4),
} spi_host_error_enable;

typedef enum [[clang::flag_enum]] spi_host_error_status : uint32_t {
    spi_host_error_status_cmdbusy = (1u << 0),
    spi_host_error_status_overflow = (1u << 1),
    spi_host_error_status_underflow = (1u << 2),
    spi_host_error_status_cmdinval = (1u << 3),
    spi_host_error_status_csidinval = (1u << 4),
    spi_host_error_status_accessinval = (1u << 5),
} spi_host_error_status;

typedef enum [[clang::flag_enum]] spi_host_event_enable : uint32_t {
    spi_host_event_enable_rxfull = (1u << 0),
    spi_host_event_enable_txempty = (1u << 1),
    spi_host_event_enable_rxwm = (1u << 2),
    spi_host_event_enable_txwm = (1u << 3),
    spi_host_event_enable_ready = (1u << 4),
    spi_host_event_enable_idle = (1u << 5),
} spi_host_event_enable;

typedef volatile struct [[gnu::aligned(4)]] spi_host_memory_layout {
    /* spi_host.intr_state (0x0) */
    spi_host_intr intr_state;

    /* spi_host.intr_enable (0x4) */
    spi_host_intr intr_enable;

    /* spi_host.intr_test (0x8) */
    spi_host_intr intr_test;

    /* spi_host.alert_test (0xc) */
    spi_host_alert_test alert_test;

    /* spi_host.control (0x10) */
    spi_host_control control;

    /* spi_host.status (0x14) */
    const spi_host_status status;

    /* spi_host.configopts (0x18) */
    spi_host_configopts configopts;

    /* spi_host.csid (0x1c) */
    uint32_t csid;

    /* spi_host.command (0x20) */
    spi_host_command command;

    const uint8_t __reserved0[0x2c - 0x24];

    /* spi_host.error_enable (0x2c) */
    spi_host_error_enable error_enable;

    /* spi_host.error_status (0x30) */
    spi_host_error_status error_status;

    /* spi_host.event_enable (0x34) */
    spi_host_event_enable event_enable;

    /* spi_host.rxdata (0x24-0x24) */
    const uint32_t rxdata[1];

    /* spi_host.txdata (0x28-0x28) */
    uint32_t txdata[1];
} *spi_host_t;

_Static_assert(__builtin_offsetof(struct spi_host_memory_layout, intr_state) == 0x0ul,
               "incorrect register intr_state offset");
_Static_assert(__builtin_offsetof(struct spi_host_memory_layout, intr_enable) == 0x4ul,
               "incorrect register intr_enable offset");
_Static_assert(__builtin_offsetof(struct spi_host_memory_layout, intr_test) == 0x8ul,
               "incorrect register intr_test offset");
_Static_assert(__builtin_offsetof(struct spi_host_memory_layout, alert_test) == 0xcul,
               "incorrect register alert_test offset");
_Static_assert(__builtin_offsetof(struct spi_host_memory_layout, control) == 0x10ul,
               "incorrect register control offset");
_Static_assert(__builtin_offsetof(struct spi_host_memory_layout, status) == 0x14ul,
               "incorrect register status offset");
_Static_assert(__builtin_offsetof(struct spi_host_memory_layout, configopts) == 0x18ul,
               "incorrect register configopts offset");
_Static_assert(__builtin_offsetof(struct spi_host_memory_layout, csid) == 0x1cul,
               "incorrect register csid offset");
_Static_assert(__builtin_offsetof(struct spi_host_memory_layout, command) == 0x20ul,
               "incorrect register command offset");
_Static_assert(__builtin_offsetof(struct spi_host_memory_layout, error_enable) == 0x2cul,
               "incorrect register error_enable offset");
_Static_assert(__builtin_offsetof(struct spi_host_memory_layout, error_status) == 0x30ul,
               "incorrect register error_status offset");
_Static_assert(__builtin_offsetof(struct spi_host_memory_layout, event_enable) == 0x34ul,
               "incorrect register event_enable offset");
_Static_assert(__builtin_offsetof(struct spi_host_memory_layout, rxdata) == 0x24ul,
               "incorrect register window rxdata offset");
_Static_assert(__builtin_offsetof(struct spi_host_memory_layout, txdata) == 0x28ul,
               "incorrect register window txdata offset");

_Static_assert(sizeof(spi_host_intr) == sizeof(uint32_t),
               "register type spi_host_intr is not register sized");
_Static_assert(sizeof(spi_host_alert_test) == sizeof(uint32_t),
               "register type spi_host_alert_test is not register sized");
_Static_assert(sizeof(spi_host_control) == sizeof(uint32_t),
               "register type spi_host_control is not register sized");
_Static_assert(sizeof(spi_host_status) == sizeof(uint32_t),
               "register type spi_host_status is not register sized");
_Static_assert(sizeof(spi_host_configopts) == sizeof(uint32_t),
               "register type spi_host_configopts is not register sized");
_Static_assert(sizeof(spi_host_command) == sizeof(uint32_t),
               "register type spi_host_command is not register sized");
_Static_assert(sizeof(spi_host_error_enable) == sizeof(uint32_t),
               "register type spi_host_error_enable is not register sized");
_Static_assert(sizeof(spi_host_error_status) == sizeof(uint32_t),
               "register type spi_host_error_status is not register sized");
_Static_assert(sizeof(spi_host_event_enable) == sizeof(uint32_t),
               "register type spi_host_event_enable is not register sized");
