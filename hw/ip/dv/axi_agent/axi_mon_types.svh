// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Enumerations for the passive AXI transaction monitor (axi_monitor / axi_mon_item).

// Direction of a monitored transaction.
typedef enum {
  AXI_READ,
  AXI_WRITE
} axi_dir_e;
