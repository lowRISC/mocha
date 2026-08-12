// Copyright lowRISC contributors
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// The signal widths used by the AXI agent's interfaces and monitored items.
//
// The axi_*_if interfaces take a "max footprint" approach: every signal is declared at the widest
// configuration the agent supports and then masked down to the width supplied through the
// set_*_width() methods. The monitored items (axi_mon_read_item / axi_mon_write_item) have to
// declare fields wide enough to hold whatever an interface captured, so both sides need the same
// numbers. They live here so there is one definition rather than a copy per file.

package axi_widths_pkg;

  // Configurable widths: the maximum an interface can be set to.
  localparam int unsigned AxiMaxIdWidth       = 32;
  localparam int unsigned AxiMaxAddrWidth     = 64;
  localparam int unsigned AxiMaxDataWidth     = 1024;
  localparam int unsigned AxiMaxReqUserWidth  = 128;  // AWUSER / ARUSER
  localparam int unsigned AxiMaxDataUserWidth = 512;  // WUSER, and the data half of RUSER
  localparam int unsigned AxiMaxRespUserWidth = 16;   // BUSER, and the response half of RUSER

  // Derived: one strobe bit per data byte, and RUSER carries both of the user fields above.
  localparam int unsigned AxiMaxStrbWidth  = AxiMaxDataWidth / 8;
  localparam int unsigned AxiMaxRUserWidth = AxiMaxDataUserWidth + AxiMaxRespUserWidth;

  // Fixed by the AXI specification, so identical in every configuration.
  localparam int unsigned AxiLenWidth    = 8;
  localparam int unsigned AxiSizeWidth   = 3;
  localparam int unsigned AxiBurstWidth  = 2;
  localparam int unsigned AxiCacheWidth  = 4;
  localparam int unsigned AxiProtWidth   = 3;
  localparam int unsigned AxiQosWidth    = 4;
  localparam int unsigned AxiRegionWidth = 4;
  localparam int unsigned AxiRespWidth   = 3;

endpackage
