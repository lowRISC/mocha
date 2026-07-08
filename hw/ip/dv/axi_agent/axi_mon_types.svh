// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Types for the passive AXI transaction monitor (axi_monitor / axi_mon_item).

// The direction-agnostic request fields carried by axi_mon_item, sized from the shared max
// footprints in axi_widths_pkg so they always match what an axi_*_if can capture. Every monitored
// field is 4-state: so a 2-state item would turn an X into a clean 0 before anything downstream
// could notice it.
typedef logic [AxiMaxIdWidth-1:0]   axi_id_t;
typedef logic [AxiMaxAddrWidth-1:0] axi_addr_t;

// Direction of a monitored transaction.
typedef enum {
  AXI_READ,
  AXI_WRITE
} axi_dir_e;
