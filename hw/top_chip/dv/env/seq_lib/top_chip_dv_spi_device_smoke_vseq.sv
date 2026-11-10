// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Read the SPI device JEDEC ID over the chip pins and check it against the value SW configured
//
// The JEDEC ID fields are randomized here and written into the SW image, and SW programs them into
// the SPI device. Once SW logs that it is done, the SPI host agent sends a Read JEDEC ID command.
class top_chip_dv_spi_device_smoke_vseq extends top_chip_dv_base_vseq;
  `uvm_object_utils(top_chip_dv_spi_device_smoke_vseq)

  localparam bit [7:0] ReadJedecOpcode = 8'h9F;

  // JEDEC ID fields written into the SW image: the continuation code, how many times it is sent
  // before the manufacturer ID, the manufacturer ID and the device ID
  local rand bit [7:0]  jedec_cc;
  local rand bit [7:0]  jedec_num_cc;
  local rand bit [7:0]  jedec_mf;
  local rand bit [15:0] jedec_device_id;

  // Keep the response short, up to the twelve continuation codes of the lowRISC manufacturer ID
  extern constraint jedec_num_cc_c;

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();

  // Methods extending base methods from top_chip_dv_base_vseq
  extern virtual task dut_init(string reset_kind = "HARD");

  // Class specific methods

  // Return the bytes the SPI device sends in response to Read JEDEC ID: the continuation codes,
  // the manufacturer ID, then the device ID least significant byte first
  extern local function void get_exp_jedec_bytes(output bit [7:0] exp_q[$]);
endclass : top_chip_dv_spi_device_smoke_vseq


constraint top_chip_dv_spi_device_smoke_vseq::jedec_num_cc_c {
  jedec_num_cc inside {[0:12]};
}

function top_chip_dv_spi_device_smoke_vseq::new(string name = "");
  super.new(name);
endfunction : new

task top_chip_dv_spi_device_smoke_vseq::body();
  spi_flash_cmd_info jedec_info = spi_flash_cmd_info::type_id::create("jedec_info");
  spi_host_flash_seq jedec_seq  = spi_host_flash_seq::type_id::create("jedec_seq");
  bit [7:0]          exp_q[$];

  super.body();

  // Command layout the agent uses to drive Read JEDEC ID, matching what SW programs in CMD_INFO_3
  jedec_info.opcode        = ReadJedecOpcode;
  jedec_info.addr_mode     = SpiFlashAddrDisabled;
  jedec_info.write_command = 0;
  jedec_info.num_lanes     = 1;
  jedec_info.dummy_cycles  = 0;
  cfg.m_spi_host_agent_cfg.add_cmd_info(jedec_info);

  `DV_WAIT(cfg.sw_test_status_vif.sw_test_status == SwTestStatusInTest)
  `DV_WAIT(cfg.sw_logger_vif.printed_log == "SPI device JEDEC ID configured")

  get_exp_jedec_bytes(exp_q);
  jedec_seq.opcode    = ReadJedecOpcode;
  jedec_seq.read_size = exp_q.size();
  jedec_seq.start(p_sequencer.spi_host_sqr);
  `uvm_info(`gfn, $sformatf("Read JEDEC ID returned %p", jedec_seq.rsp.payload_q), UVM_LOW)

  foreach (exp_q[i]) begin
    if (jedec_seq.rsp.payload_q[i] !== exp_q[i]) begin
      `uvm_error(`gfn, $sformatf("Read JEDEC ID returned %p, expected %p",
                                 jedec_seq.rsp.payload_q, exp_q))
      break;
    end
  end
endtask : body

task top_chip_dv_spi_device_smoke_vseq::dut_init(string reset_kind = "HARD");
  super.dut_init(reset_kind);

  sw_symbol_backdoor_overwrite("jedec_cc", '{jedec_cc});
  sw_symbol_backdoor_overwrite("jedec_num_cc", '{jedec_num_cc});
  sw_symbol_backdoor_overwrite("jedec_mf", '{jedec_mf});
  sw_symbol_backdoor_overwrite("jedec_device_id", '{jedec_device_id[7:0], jedec_device_id[15:8]});
endtask : dut_init

function void top_chip_dv_spi_device_smoke_vseq::get_exp_jedec_bytes(output bit [7:0] exp_q[$]);
  repeat (jedec_num_cc) begin
    exp_q.push_back(jedec_cc);
  end
  exp_q.push_back(jedec_mf);
  exp_q.push_back(jedec_device_id[7:0]);
  exp_q.push_back(jedec_device_id[15:8]);
endfunction : get_exp_jedec_bytes
