// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Binds axi_sram_assert into every axi_sram instance.

bind axi_sram axi_sram_assert u_axi_sram_assert (
  .clk_i,
  .rst_ni,
  .axi_req_i,
  .axi_resp_o,
  .sram_req,
  .sram_we_d,
  .sram_be,
  .sram_cheri_w_tag
);
