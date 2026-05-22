// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// This checks that the outgoing resets and the corresponding reset enable going to alert handler
// are shifted by a single clock cycle.
interface rstmgr_rst_en_track_sva_if (
  input rstmgr_pkg::rstmgr_out_t resets_i,
  input rstmgr_pkg::rstmgr_rst_en_t reset_en_i,
  input logic clk_aon_i,
  input logic clk_io_i,
  input logic clk_main_i,
  input logic rst_por_ni
);
  import rstmgr_pkg::DomainAonSel;
  import rstmgr_pkg::DomainMainSel;
  localparam int DELAY = 1;

  `ASSERT(DMainRstPorAonEnTracksRstPorAonActive_A,
          $fell(resets_i.rst_por_aon_n[DomainMainSel]) |-> ##[0:DELAY]
          reset_en_i.por_aon[DomainMainSel] == prim_mubi_pkg::MuBi4True,
          clk_aon_i,
          !rst_por_ni)

  `ASSERT(DMainRstPorAonEnTracksRstPorAonInactive_A,
          $rose(resets_i.rst_por_aon_n[DomainMainSel]) |-> ##DELAY
          !resets_i.rst_por_aon_n[DomainMainSel] ||
          reset_en_i.por_aon[DomainMainSel] == prim_mubi_pkg::MuBi4False,
          clk_aon_i,
          !rst_por_ni)

  `ASSERT(DAonRstPorAonEnTracksRstPorAonActive_A,
          $fell(resets_i.rst_por_aon_n[DomainAonSel]) |-> ##[0:DELAY]
          reset_en_i.por_aon[DomainAonSel] == prim_mubi_pkg::MuBi4True,
          clk_aon_i,
          !rst_por_ni)

  `ASSERT(DAonRstPorAonEnTracksRstPorAonInactive_A,
          $rose(resets_i.rst_por_aon_n[DomainAonSel]) |-> ##DELAY
          !resets_i.rst_por_aon_n[DomainAonSel] ||
          reset_en_i.por_aon[DomainAonSel] == prim_mubi_pkg::MuBi4False,
          clk_aon_i,
          !rst_por_ni)

  `ASSERT(DAonRstPorEnTracksRstPorActive_A,
          $fell(resets_i.rst_por_n[DomainAonSel]) |-> ##[0:DELAY]
          reset_en_i.por[DomainAonSel] == prim_mubi_pkg::MuBi4True,
          clk_main_i,
          !rst_por_ni)

  `ASSERT(DAonRstPorEnTracksRstPorInactive_A,
          $rose(resets_i.rst_por_n[DomainAonSel]) |-> ##DELAY
          !resets_i.rst_por_n[DomainAonSel] ||
          reset_en_i.por[DomainAonSel] == prim_mubi_pkg::MuBi4False,
          clk_main_i,
          !rst_por_ni)

  `ASSERT(DAonRstPorIoEnTracksRstPorIoActive_A,
          $fell(resets_i.rst_por_io_n[DomainAonSel]) |-> ##[0:DELAY]
          reset_en_i.por_io[DomainAonSel] == prim_mubi_pkg::MuBi4True,
          clk_io_i,
          !rst_por_ni)

  `ASSERT(DAonRstPorIoEnTracksRstPorIoInactive_A,
          $rose(resets_i.rst_por_io_n[DomainAonSel]) |-> ##DELAY
          !resets_i.rst_por_io_n[DomainAonSel] ||
          reset_en_i.por_io[DomainAonSel] == prim_mubi_pkg::MuBi4False,
          clk_io_i,
          !rst_por_ni)

  `ASSERT(DMainRstMainEnTracksRstMainActive_A,
          $fell(resets_i.rst_main_n[DomainMainSel]) |-> ##[0:DELAY]
          reset_en_i.main[DomainMainSel] == prim_mubi_pkg::MuBi4True,
          clk_main_i,
          !rst_por_ni)

  `ASSERT(DMainRstMainEnTracksRstMainInactive_A,
          $rose(resets_i.rst_main_n[DomainMainSel]) |-> ##DELAY
          !resets_i.rst_main_n[DomainMainSel] ||
          reset_en_i.main[DomainMainSel] == prim_mubi_pkg::MuBi4False,
          clk_main_i,
          !rst_por_ni)

  `ASSERT(DMainRstIoEnTracksRstIoActive_A,
          $fell(resets_i.rst_io_n[DomainMainSel]) |-> ##[0:DELAY]
          reset_en_i.io[DomainMainSel] == prim_mubi_pkg::MuBi4True,
          clk_io_i,
          !rst_por_ni)

  `ASSERT(DMainRstIoEnTracksRstIoInactive_A,
          $rose(resets_i.rst_io_n[DomainMainSel]) |-> ##DELAY
          !resets_i.rst_io_n[DomainMainSel] ||
          reset_en_i.io[DomainMainSel] == prim_mubi_pkg::MuBi4False,
          clk_io_i,
          !rst_por_ni)

  `ASSERT(DMainRstSpiDeviceEnTracksRstSpiDeviceActive_A,
          $fell(resets_i.rst_spi_device_n[DomainMainSel]) |-> ##[0:DELAY]
          reset_en_i.spi_device[DomainMainSel] == prim_mubi_pkg::MuBi4True,
          clk_io_i,
          !rst_por_ni)

  `ASSERT(DMainRstSpiDeviceEnTracksRstSpiDeviceInactive_A,
          $rose(resets_i.rst_spi_device_n[DomainMainSel]) |-> ##DELAY
          !resets_i.rst_spi_device_n[DomainMainSel] ||
          reset_en_i.spi_device[DomainMainSel] == prim_mubi_pkg::MuBi4False,
          clk_io_i,
          !rst_por_ni)

  `ASSERT(DMainRstSpiHostEnTracksRstSpiHostActive_A,
          $fell(resets_i.rst_spi_host_n[DomainMainSel]) |-> ##[0:DELAY]
          reset_en_i.spi_host[DomainMainSel] == prim_mubi_pkg::MuBi4True,
          clk_io_i,
          !rst_por_ni)

  `ASSERT(DMainRstSpiHostEnTracksRstSpiHostInactive_A,
          $rose(resets_i.rst_spi_host_n[DomainMainSel]) |-> ##DELAY
          !resets_i.rst_spi_host_n[DomainMainSel] ||
          reset_en_i.spi_host[DomainMainSel] == prim_mubi_pkg::MuBi4False,
          clk_io_i,
          !rst_por_ni)

  `ASSERT(DMainRstI2cEnTracksRstI2cActive_A,
          $fell(resets_i.rst_i2c_n[DomainMainSel]) |-> ##[0:DELAY]
          reset_en_i.i2c[DomainMainSel] == prim_mubi_pkg::MuBi4True,
          clk_io_i,
          !rst_por_ni)

  `ASSERT(DMainRstI2cEnTracksRstI2cInactive_A,
          $rose(resets_i.rst_i2c_n[DomainMainSel]) |-> ##DELAY
          !resets_i.rst_i2c_n[DomainMainSel] ||
          reset_en_i.i2c[DomainMainSel] == prim_mubi_pkg::MuBi4False,
          clk_io_i,
          !rst_por_ni)

endinterface
