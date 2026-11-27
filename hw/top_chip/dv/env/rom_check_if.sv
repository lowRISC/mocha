// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Observe the boot-time ROM check between rom_ctrl and pwrmgr
//
// tb.sv connects the ports to the nets between the two blocks in top_chip_system, so that a
// virtual sequence can see the result of the check and pwrmgr's decision without naming DUT
// hierarchy.
interface rom_check_if (
  // rom_ctrl's report to pwrmgr: done once rom_ctrl has compared the digest of the ROM contents
  // with the expected digest in the top words of the ROM, and good if the two matched
  input wire rom_ctrl_pkg::pwrmgr_data_t pwrmgr_data_i,
  // pwrmgr's fetch enable. Anything but On keeps u_rom_isolate closed, which stalls every access
  // from CVA6 to the ROM.
  input wire lc_ctrl_pkg::lc_tx_t        fetch_en_i
);
endinterface : rom_check_if
