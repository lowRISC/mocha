// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Nicole Narr <narrn@ethz.ch>
// - Christopher Reinwardt <creinwar@ethz.ch>
// Date:   17.11.2022

// Macros to define AXI_LLC types and structs

`ifndef AXI_LLC_TYPEDEF_SVH_
`define AXI_LLC_TYPEDEF_SVH_

////////////////////////////////////////////////////////////////////////////////////////////////////
// Configuration registers type definitions
//
// HW -> Registers
//
// Fields
// * cfg_spm:       Data to be written into the SPM config register
// * cfg_spm_en:    SPM config register write enable
// * cfg_flush:     Data to be written into the flush config register
// * cfg_flush_en:  Flush config register write enable
// * commit_cfg:    Configuration commit register - Cleared by hardware
// * commit_cfg_en: Configuration commit register write enable
// * flushed:       Flush completion info register
// * flushed_en:    Flush completion info register write enable
// * bist_out:      Result of the BIST
// * bist_out_en:   BIST info write enable
// * set_asso:      Set associativity info register
// * set_asso_en:   Set associativity info register write enable
// * num_lines:     Amount of lines info register
// * num_lines_en:  Amount of lines info register write enable
// * num_blocks:    Amount of blocks info register
// * num_blocks_en: Amount of blocks info register write enable
// * version:       Version register
// * version_en:    Version register write enable
`define AXI_LLC_TYPEDEF_REGS_D_T(cfg_regs_d_t, reg_data_t, set_asso_t)  \
  typedef struct packed {                                               \
    set_asso_t  cfg_spm;                                                \
    logic       cfg_spm_en;                                             \
    set_asso_t  cfg_flush;                                              \
    logic       cfg_flush_en;                                           \
    logic       commit_cfg;                                             \
    logic       commit_cfg_en;                                          \
    set_asso_t  flushed;                                                \
    logic       flushed_en;                                             \
    set_asso_t  bist_out;                                               \
    logic       bist_out_en;                                            \
    logic       bist_status_done;                                       \
    logic       bist_status_en;                                         \
    reg_data_t  set_asso;                                               \
    logic       set_asso_en;                                            \
    reg_data_t  num_lines;                                              \
    logic       num_lines_en;                                           \
    reg_data_t  num_blocks;                                             \
    logic       num_blocks_en;                                          \
    reg_data_t  version;                                                \
    logic       version_en;                                             \
  } cfg_regs_d_t;

// Registers -> HW
//
// Fields
// * cfg_spm:       Data from the SPM config register
// * cfg_flush:     Data from the flush config register
// * commit_cfg:    Bit from the configuration commit register - Set by SW
// * flushed:       Data from flush completion register
`define AXI_LLC_TYPEDEF_REGS_Q_T(cfg_regs_q_t, reg_data_t, set_asso_t)  \
  typedef struct packed {                                               \
    set_asso_t  cfg_spm;                                                \
    set_asso_t  cfg_flush;                                              \
    logic       commit_cfg;                                             \
    set_asso_t  flushed;                                                \
  } cfg_regs_q_t;

////////////////////////////////////////////////////////////////////////////////////////////////////

`define AXI_LLC_TYPEDEF_ALL(__name, __reg_data_t, __set_asso_t) \
  `AXI_LLC_TYPEDEF_REGS_D_T(__name``_cfg_regs_d_t, __reg_data_t, __set_asso_t) \
  `AXI_LLC_TYPEDEF_REGS_Q_T(__name``_cfg_regs_q_t, __reg_data_t, __set_asso_t)

`endif