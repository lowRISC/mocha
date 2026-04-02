// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`ifndef AXI4_VIP_TYPES_SVH
`define AXI4_VIP_TYPES_SVH

typedef enum {AXI_READ, AXI_WRITE} axi_dir_t;

typedef enum {
  AXI_AW_CH,
  AXI_W_CH,
  AXI_FULL_WRITE_TR,
  AXI_AR_CH,
  AXI_R_CH,
  AXI_FULL_READ_TR
} axi_obs_t;

`endif // AXI4_VIP_TYPES_SVH