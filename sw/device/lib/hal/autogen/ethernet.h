// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Auto-generated: 'util/rdlgenerator.py gen-device-headers build/rdl/rdl.json sw/device/lib/hal/autogen'

#pragma once

#include <stdbool.h>
#include <stdint.h>

typedef enum [[clang::flag_enum]] ethernet_intr : uint32_t {
    ethernet_intr_none = 0,
    ethernet_intr_rx_not_empty = (1u << 0),
    ethernet_intr_rx_table_almost_full = (1u << 1),
    ethernet_intr_rx_table_full = (1u << 2),
    ethernet_intr_rx_buf_almost_full = (1u << 3),
    ethernet_intr_packet_lost = (1u << 4),
    ethernet_intr_tx_done = (1u << 5),
    ethernet_intr_manual_irq = (1u << 6),
} ethernet_intr;

typedef struct [[gnu::aligned(4)]] {
    uint32_t set_manual_irq : 1;
    uint32_t : 31;
} ethernet_intr_test;

typedef enum [[clang::flag_enum]] ethernet_ctrl : uint32_t {
    ethernet_ctrl_none = 0,
    ethernet_ctrl_promiscuous_mode = (1u << 0),
    ethernet_ctrl_loopback = (1u << 1),
} ethernet_ctrl;

typedef struct [[gnu::aligned(4)]] {
    uint32_t rx_not_empty : 1;
    uint32_t rx_table_almost_full : 1;
    uint32_t rx_table_full : 1;
    uint32_t rx_buf_almost_full : 1;
    uint32_t packet_lost : 1;
    uint32_t : 2;
    uint32_t tx_busy : 1;
    uint32_t n_packets_in_rx_buf : 4;
    uint32_t : 20;
} ethernet_status;

typedef struct [[gnu::aligned(4)]] {
    uint32_t mac_hi : 16;
    uint32_t : 16;
} ethernet_machi;

typedef struct [[gnu::aligned(4)]] {
    uint32_t tx_packet_len : 11;
    uint32_t : 21;
} ethernet_tx_ctrl;

typedef struct [[gnu::aligned(4)]] {
    uint32_t pop : 1;
    uint32_t : 31;
} ethernet_rx_pop;

typedef enum [[clang::flag_enum]] ethernet_mdio_ctrl : uint32_t {
    ethernet_mdio_ctrl_none = 0,
    ethernet_mdio_ctrl_mdio_clk = (1u << 0),
    ethernet_mdio_ctrl_mdio_o = (1u << 1),
    ethernet_mdio_ctrl_mdio_oen = (1u << 2),
    ethernet_mdio_ctrl_mdio_i = (1u << 3),
} ethernet_mdio_ctrl;

typedef volatile struct [[gnu::aligned(4)]] ethernet_memory_layout {
    const uint8_t __reserved0[0x800 - 0x0];

    /* ethernet.intr_state (0x800) */
    ethernet_intr intr_state;

    /* ethernet.intr_mask (0x804) */
    ethernet_intr intr_mask;

    /* ethernet.intr_test (0x808) */
    ethernet_intr_test intr_test;

    const uint8_t __reserved1[0x810 - 0x80c];

    /* ethernet.ctrl (0x810) */
    ethernet_ctrl ctrl;

    /* ethernet.status (0x814) */
    const ethernet_status status;

    /* ethernet.maclo (0x818) */
    uint32_t maclo;

    /* ethernet.machi (0x81c) */
    ethernet_machi machi;

    /* ethernet.tx_ctrl (0x820) */
    ethernet_tx_ctrl tx_ctrl;

    const uint8_t __reserved2[0x828 - 0x824];

    /* ethernet.rx_pop (0x828) */
    ethernet_rx_pop rx_pop;

    /* ethernet.mdio_ctrl (0x82c) */
    ethernet_mdio_ctrl mdio_ctrl;

    const uint8_t __reserved3[0x1000 - 0x830];

    /* ethernet.tx_data_buf (0x1000-0x17f8) */
    uint64_t tx_data_buf[256];

    const uint8_t __reserved4[0x4000 - 0x1800];

    /* ethernet.rx_data_buf (0x4000-0x5ff8) */
    const uint64_t rx_data_buf[1024];

    /* ethernet.rx_desc_table (0x6000-0x6038) */
    const uint64_t rx_desc_table[8];
} *ethernet_t;

_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, intr_state) == 0x800ul,
               "incorrect register intr_state offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, intr_mask) == 0x804ul,
               "incorrect register intr_mask offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, intr_test) == 0x808ul,
               "incorrect register intr_test offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, ctrl) == 0x810ul,
               "incorrect register ctrl offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, status) == 0x814ul,
               "incorrect register status offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, maclo) == 0x818ul,
               "incorrect register maclo offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, machi) == 0x81cul,
               "incorrect register machi offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, tx_ctrl) == 0x820ul,
               "incorrect register tx_ctrl offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, rx_pop) == 0x828ul,
               "incorrect register rx_pop offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, mdio_ctrl) == 0x82cul,
               "incorrect register mdio_ctrl offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, tx_data_buf) == 0x1000ul,
               "incorrect register window tx_data_buf offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, rx_data_buf) == 0x4000ul,
               "incorrect register window rx_data_buf offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, rx_desc_table) == 0x6000ul,
               "incorrect register window rx_desc_table offset");

_Static_assert(sizeof(ethernet_intr) == sizeof(uint32_t),
               "register type ethernet_intr is not register sized");
_Static_assert(sizeof(ethernet_intr_test) == sizeof(uint32_t),
               "register type ethernet_intr_test is not register sized");
_Static_assert(sizeof(ethernet_ctrl) == sizeof(uint32_t),
               "register type ethernet_ctrl is not register sized");
_Static_assert(sizeof(ethernet_status) == sizeof(uint32_t),
               "register type ethernet_status is not register sized");
_Static_assert(sizeof(ethernet_machi) == sizeof(uint32_t),
               "register type ethernet_machi is not register sized");
_Static_assert(sizeof(ethernet_tx_ctrl) == sizeof(uint32_t),
               "register type ethernet_tx_ctrl is not register sized");
_Static_assert(sizeof(ethernet_rx_pop) == sizeof(uint32_t),
               "register type ethernet_rx_pop is not register sized");
_Static_assert(sizeof(ethernet_mdio_ctrl) == sizeof(uint32_t),
               "register type ethernet_mdio_ctrl is not register sized");
