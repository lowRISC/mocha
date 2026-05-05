// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Auto-generated: 'util/rdlgenerator.py gen-device-headers build/rdl/rdl.json sw/device/lib/hal/autogen'

#pragma once

#include <stdbool.h>
#include <stdint.h>

typedef struct [[gnu::aligned(4)]] {
    uint32_t mac_addr_hi : 16;
    uint32_t cooked : 1;
    uint32_t loopback : 1;
    uint32_t spare : 4;
    uint32_t promiscuous : 1;
    uint32_t irq_en : 1;
    uint32_t : 8;
} ethernet_machi;

typedef struct [[gnu::aligned(4)]] {
    uint32_t packet_len : 11;
    uint32_t : 5;
    uint32_t frame_addr : 11;
    uint32_t : 4;
    uint32_t busy : 1;
} ethernet_tplr;

typedef enum [[clang::flag_enum]] ethernet_mdioctrl : uint32_t {
    ethernet_mdioctrl_mdioclk = (1u << 0),
    ethernet_mdioctrl_mdioout = (1u << 1),
    ethernet_mdioctrl_mdiooen = (1u << 2),
    ethernet_mdioctrl_mdioin = (1u << 3),
} ethernet_mdioctrl;

typedef struct [[gnu::aligned(4)]] {
    uint32_t last_buf : 4;
    uint32_t : 28;
} ethernet_rfcs;

typedef struct [[gnu::aligned(4)]] {
    uint32_t first_buf : 4;
    uint32_t next_buf : 4;
    uint32_t last_buf : 4;
    uint32_t rx_avail : 1;
    uint32_t rx_irq : 1;
    uint32_t : 18;
} ethernet_rsr;

typedef struct [[gnu::aligned(4)]] {
    uint32_t packet_len : 11;
    uint32_t : 21;
} ethernet_rplr0;

typedef struct [[gnu::aligned(4)]] {
    uint32_t packet_len : 11;
    uint32_t : 21;
} ethernet_rplr1;

typedef struct [[gnu::aligned(4)]] {
    uint32_t packet_len : 11;
    uint32_t : 21;
} ethernet_rplr2;

typedef struct [[gnu::aligned(4)]] {
    uint32_t packet_len : 11;
    uint32_t : 21;
} ethernet_rplr3;

typedef struct [[gnu::aligned(4)]] {
    uint32_t packet_len : 11;
    uint32_t : 21;
} ethernet_rplr4;

typedef struct [[gnu::aligned(4)]] {
    uint32_t packet_len : 11;
    uint32_t : 21;
} ethernet_rplr5;

typedef struct [[gnu::aligned(4)]] {
    uint32_t packet_len : 11;
    uint32_t : 21;
} ethernet_rplr6;

typedef struct [[gnu::aligned(4)]] {
    uint32_t packet_len : 11;
    uint32_t : 21;
} ethernet_rplr7;

typedef volatile struct [[gnu::aligned(4)]] ethernet_memory_layout {
    const uint8_t __reserved0[0x800 - 0x0];

    /* ethernet.maclo (0x800) */
    uint32_t maclo;

    const uint8_t __reserved1[0x808 - 0x804];

    /* ethernet.machi (0x808) */
    ethernet_machi machi;

    const uint8_t __reserved2[0x810 - 0x80c];

    /* ethernet.tplr (0x810) */
    ethernet_tplr tplr;

    const uint8_t __reserved3[0x818 - 0x814];

    /* ethernet.tfcs (0x818) */
    uint32_t tfcs;

    const uint8_t __reserved4[0x820 - 0x81c];

    /* ethernet.mdioctrl (0x820) */
    ethernet_mdioctrl mdioctrl;

    const uint8_t __reserved5[0x828 - 0x824];

    /* ethernet.rfcs (0x828) */
    ethernet_rfcs rfcs;

    const uint8_t __reserved6[0x830 - 0x82c];

    /* ethernet.rsr (0x830) */
    ethernet_rsr rsr;

    const uint8_t __reserved7[0x840 - 0x834];

    /* ethernet.rplr0 (0x840) */
    const ethernet_rplr0 rplr0;

    const uint8_t __reserved8[0x848 - 0x844];

    /* ethernet.rplr1 (0x848) */
    const ethernet_rplr1 rplr1;

    const uint8_t __reserved9[0x850 - 0x84c];

    /* ethernet.rplr2 (0x850) */
    const ethernet_rplr2 rplr2;

    const uint8_t __reserved10[0x858 - 0x854];

    /* ethernet.rplr3 (0x858) */
    const ethernet_rplr3 rplr3;

    const uint8_t __reserved11[0x860 - 0x85c];

    /* ethernet.rplr4 (0x860) */
    const ethernet_rplr4 rplr4;

    const uint8_t __reserved12[0x868 - 0x864];

    /* ethernet.rplr5 (0x868) */
    const ethernet_rplr5 rplr5;

    const uint8_t __reserved13[0x870 - 0x86c];

    /* ethernet.rplr6 (0x870) */
    const ethernet_rplr6 rplr6;

    const uint8_t __reserved14[0x878 - 0x874];

    /* ethernet.rplr7 (0x878) */
    const ethernet_rplr7 rplr7;

    const uint8_t __reserved15[0x1000 - 0x87c];

    /* ethernet.tx_buffer (0x1000-0x17fc) */
    uint32_t tx_buffer[256];

    const uint8_t __reserved16[0x4000 - 0x1800];

    /* ethernet.rx_buffer0 (0x4000-0x47fc) */
    uint32_t rx_buffer0[256];

    /* ethernet.rx_buffer1 (0x4800-0x4ffc) */
    uint32_t rx_buffer1[256];

    /* ethernet.rx_buffer2 (0x5000-0x57fc) */
    uint32_t rx_buffer2[256];

    /* ethernet.rx_buffer3 (0x5800-0x5ffc) */
    uint32_t rx_buffer3[256];

    /* ethernet.rx_buffer4 (0x6000-0x67fc) */
    uint32_t rx_buffer4[256];

    /* ethernet.rx_buffer5 (0x6800-0x6ffc) */
    uint32_t rx_buffer5[256];

    /* ethernet.rx_buffer6 (0x7000-0x77fc) */
    uint32_t rx_buffer6[256];

    /* ethernet.rx_buffer7 (0x7800-0x7ffc) */
    uint32_t rx_buffer7[256];
} *ethernet_t;

_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, maclo) == 0x800ul,
               "incorrect register maclo offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, machi) == 0x808ul,
               "incorrect register machi offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, tplr) == 0x810ul,
               "incorrect register tplr offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, tfcs) == 0x818ul,
               "incorrect register tfcs offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, mdioctrl) == 0x820ul,
               "incorrect register mdioctrl offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, rfcs) == 0x828ul,
               "incorrect register rfcs offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, rsr) == 0x830ul,
               "incorrect register rsr offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, rplr0) == 0x840ul,
               "incorrect register rplr0 offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, rplr1) == 0x848ul,
               "incorrect register rplr1 offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, rplr2) == 0x850ul,
               "incorrect register rplr2 offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, rplr3) == 0x858ul,
               "incorrect register rplr3 offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, rplr4) == 0x860ul,
               "incorrect register rplr4 offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, rplr5) == 0x868ul,
               "incorrect register rplr5 offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, rplr6) == 0x870ul,
               "incorrect register rplr6 offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, rplr7) == 0x878ul,
               "incorrect register rplr7 offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, tx_buffer) == 0x1000ul,
               "incorrect register window tx_buffer offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, rx_buffer0) == 0x4000ul,
               "incorrect register window rx_buffer0 offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, rx_buffer1) == 0x4800ul,
               "incorrect register window rx_buffer1 offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, rx_buffer2) == 0x5000ul,
               "incorrect register window rx_buffer2 offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, rx_buffer3) == 0x5800ul,
               "incorrect register window rx_buffer3 offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, rx_buffer4) == 0x6000ul,
               "incorrect register window rx_buffer4 offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, rx_buffer5) == 0x6800ul,
               "incorrect register window rx_buffer5 offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, rx_buffer6) == 0x7000ul,
               "incorrect register window rx_buffer6 offset");
_Static_assert(__builtin_offsetof(struct ethernet_memory_layout, rx_buffer7) == 0x7800ul,
               "incorrect register window rx_buffer7 offset");

_Static_assert(sizeof(ethernet_machi) == sizeof(uint32_t),
               "register type ethernet_machi is not register sized");
_Static_assert(sizeof(ethernet_tplr) == sizeof(uint32_t),
               "register type ethernet_tplr is not register sized");
_Static_assert(sizeof(ethernet_mdioctrl) == sizeof(uint32_t),
               "register type ethernet_mdioctrl is not register sized");
_Static_assert(sizeof(ethernet_rfcs) == sizeof(uint32_t),
               "register type ethernet_rfcs is not register sized");
_Static_assert(sizeof(ethernet_rsr) == sizeof(uint32_t),
               "register type ethernet_rsr is not register sized");
_Static_assert(sizeof(ethernet_rplr0) == sizeof(uint32_t),
               "register type ethernet_rplr0 is not register sized");
_Static_assert(sizeof(ethernet_rplr1) == sizeof(uint32_t),
               "register type ethernet_rplr1 is not register sized");
_Static_assert(sizeof(ethernet_rplr2) == sizeof(uint32_t),
               "register type ethernet_rplr2 is not register sized");
_Static_assert(sizeof(ethernet_rplr3) == sizeof(uint32_t),
               "register type ethernet_rplr3 is not register sized");
_Static_assert(sizeof(ethernet_rplr4) == sizeof(uint32_t),
               "register type ethernet_rplr4 is not register sized");
_Static_assert(sizeof(ethernet_rplr5) == sizeof(uint32_t),
               "register type ethernet_rplr5 is not register sized");
_Static_assert(sizeof(ethernet_rplr6) == sizeof(uint32_t),
               "register type ethernet_rplr6 is not register sized");
_Static_assert(sizeof(ethernet_rplr7) == sizeof(uint32_t),
               "register type ethernet_rplr7 is not register sized");
