// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Auto-generated: 'util/rdlgenerator.py gen-device-headers build/rdl/rdl.json sw/device/lib/hal/autogen'

#pragma once

#include <stdbool.h>
#include <stdint.h>

typedef struct [[gnu::aligned(4)]] {
    uint32_t prio : 2;
    uint32_t : 30;
} plic_prio;

typedef struct [[gnu::aligned(4)]] {
    uint32_t threshold0 : 2;
    uint32_t : 30;
} plic_threshold0;

typedef struct [[gnu::aligned(4)]] {
    uint32_t cc0 : 5;
    uint32_t : 27;
} plic_cc0;

typedef struct [[gnu::aligned(4)]] {
    uint32_t threshold1 : 2;
    uint32_t : 30;
} plic_threshold1;

typedef struct [[gnu::aligned(4)]] {
    uint32_t cc1 : 5;
    uint32_t : 27;
} plic_cc1;

typedef struct [[gnu::aligned(4)]] {
    uint32_t msip0 : 1;
    uint32_t : 31;
} plic_msip0;

typedef struct [[gnu::aligned(4)]] {
    uint32_t msip1 : 1;
    uint32_t : 31;
} plic_msip1;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fatal_fault : 1;
    uint32_t : 31;
} plic_alert_test;

typedef volatile struct [[gnu::aligned(4)]] plic_memory_layout {
    /* plic.prio (0x0-0x7c) */
    plic_prio prio[32];

    const uint8_t __reserved0[0x1000 - 0x80];

    /* plic.ip (0x1000) */
    const uint32_t ip;

    const uint8_t __reserved1[0x2000 - 0x1004];

    /* plic.ie0 (0x2000) */
    uint32_t ie0;

    const uint8_t __reserved2[0x2100 - 0x2004];

    /* plic.ie1 (0x2100) */
    uint32_t ie1;

    const uint8_t __reserved3[0x200000 - 0x2104];

    /* plic.threshold0 (0x200000) */
    plic_threshold0 threshold0;

    /* plic.cc0 (0x200004) */
    plic_cc0 cc0;

    const uint8_t __reserved4[0x201000 - 0x200008];

    /* plic.threshold1 (0x201000) */
    plic_threshold1 threshold1;

    /* plic.cc1 (0x201004) */
    plic_cc1 cc1;

    const uint8_t __reserved5[0x4000000 - 0x201008];

    /* plic.msip0 (0x4000000) */
    plic_msip0 msip0;

    /* plic.msip1 (0x4000004) */
    plic_msip1 msip1;

    const uint8_t __reserved6[0x4004000 - 0x4000008];

    /* plic.alert_test (0x4004000) */
    plic_alert_test alert_test;
} *plic_t;

_Static_assert(__builtin_offsetof(struct plic_memory_layout, prio) == 0x0ul,
               "incorrect register prio offset");
_Static_assert(__builtin_offsetof(struct plic_memory_layout, ip) == 0x1000ul,
               "incorrect register ip offset");
_Static_assert(__builtin_offsetof(struct plic_memory_layout, ie0) == 0x2000ul,
               "incorrect register ie0 offset");
_Static_assert(__builtin_offsetof(struct plic_memory_layout, ie1) == 0x2100ul,
               "incorrect register ie1 offset");
_Static_assert(__builtin_offsetof(struct plic_memory_layout, threshold0) == 0x200000ul,
               "incorrect register threshold0 offset");
_Static_assert(__builtin_offsetof(struct plic_memory_layout, cc0) == 0x200004ul,
               "incorrect register cc0 offset");
_Static_assert(__builtin_offsetof(struct plic_memory_layout, threshold1) == 0x201000ul,
               "incorrect register threshold1 offset");
_Static_assert(__builtin_offsetof(struct plic_memory_layout, cc1) == 0x201004ul,
               "incorrect register cc1 offset");
_Static_assert(__builtin_offsetof(struct plic_memory_layout, msip0) == 0x4000000ul,
               "incorrect register msip0 offset");
_Static_assert(__builtin_offsetof(struct plic_memory_layout, msip1) == 0x4000004ul,
               "incorrect register msip1 offset");
_Static_assert(__builtin_offsetof(struct plic_memory_layout, alert_test) == 0x4004000ul,
               "incorrect register alert_test offset");

_Static_assert(sizeof(plic_prio) == sizeof(uint32_t),
               "register type plic_prio is not register sized");
_Static_assert(sizeof(plic_threshold0) == sizeof(uint32_t),
               "register type plic_threshold0 is not register sized");
_Static_assert(sizeof(plic_cc0) == sizeof(uint32_t),
               "register type plic_cc0 is not register sized");
_Static_assert(sizeof(plic_threshold1) == sizeof(uint32_t),
               "register type plic_threshold1 is not register sized");
_Static_assert(sizeof(plic_cc1) == sizeof(uint32_t),
               "register type plic_cc1 is not register sized");
_Static_assert(sizeof(plic_msip0) == sizeof(uint32_t),
               "register type plic_msip0 is not register sized");
_Static_assert(sizeof(plic_msip1) == sizeof(uint32_t),
               "register type plic_msip1 is not register sized");
_Static_assert(sizeof(plic_alert_test) == sizeof(uint32_t),
               "register type plic_alert_test is not register sized");
