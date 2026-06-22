// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class top_chip_dv_i2c_device_tx_rx_vseq extends top_chip_dv_i2c_tx_rx_vseq;
  `uvm_object_utils(top_chip_dv_i2c_device_tx_rx_vseq)

  // TODO: Remove once #600 is merged. This is maintained by SW to make this Vseq in sync
  bit [7:0] tx_fifo_wr_done[1];

  local rand bit [7:0] device_addr0[1];
  local rand bit [7:0] device_addr1[1];
  local rand bit       xfer_addr;

  extern function new(string name="");
  extern virtual task dut_init(string reset_kind = "HARD");

  // Fill in the I2C transfer fields before driving it
  extern local function void fill_i2c_xfer_flds(i2c_item item, rw_e dir, bus_op_e bus_op);

  // Creates and starts the transfer
  extern local task create_and_drive_i2c_xfer(i2c_item            item,
                                              rw_e                dir,
                                              bus_op_e            bus_op,
                                              i2c_target_base_seq host_seq);



  // Convert the I2C transfer packet into the form which is understandable by the I2C driver
  extern local function void conv_i2c_xfer_to_drv_type(ref i2c_item item_q[$], i2c_item xfer);

  // Label the packet in the transfer with drv_type_e and assign wdata. i2c_driver takes an action
  // based on the label.
  extern local function i2c_item assign_drv_type_and_wdata(drv_type_e drv_type, bit [7:0] data);

  // Manage the I2C transfer
  extern local task i2c_xfer();
  extern task body();
endclass : top_chip_dv_i2c_device_tx_rx_vseq

function top_chip_dv_i2c_device_tx_rx_vseq::new(string name = "");
  super.new(name);
endfunction

task top_chip_dv_i2c_device_tx_rx_vseq::dut_init(string reset_kind = "HARD");
  super.dut_init(reset_kind);
  // Read the timing parameters through SW backdoor load
  sw_symbol_backdoor_read("sys_clk_period_ns", sw_sys_clk_period_ns);
  sw_symbol_backdoor_read("scl_low_time_ns", sw_scl_low_time_ns);
  sw_symbol_backdoor_read("scl_high_time_ns", sw_scl_high_time_ns);
  sw_symbol_backdoor_read("setup_data_time_ns", sw_data_setup_time_ns);
  sw_symbol_backdoor_read("hold_data_time_ns", sw_data_hold_time_ns);
  sw_symbol_backdoor_read("setup_start_time_ns", sw_setup_start_time_ns);
  sw_symbol_backdoor_read("hold_start_time_ns", sw_hold_start_time_ns);
  sw_symbol_backdoor_read("setup_stop_time_ns", sw_setup_stop_time_ns);
  sw_symbol_backdoor_read("hold_stop_time_ns", sw_hold_stop_time_ns);
  sw_symbol_backdoor_read("rise_time_ns", sw_rise_time_ns);
  sw_symbol_backdoor_read("fall_time_ns", sw_fall_time_ns);

  // Overwrite the SW symbol with the randomized value
  sw_symbol_backdoor_overwrite("byte_count", xfer_bytes);
  sw_symbol_backdoor_overwrite("device_addr0", device_addr0);
  sw_symbol_backdoor_overwrite("device_addr1", device_addr1);

  scl_low_cycles     = round_up_divide({sw_scl_low_time_ns[1], sw_scl_low_time_ns[0]},
                                       sw_sys_clk_period_ns[0]);
  scl_high_cycles    = round_up_divide({sw_scl_high_time_ns[1], sw_scl_high_time_ns[0]},
                                       sw_sys_clk_period_ns[0]);
  sda_setup_cycles   = round_up_divide({sw_data_setup_time_ns[1], sw_data_setup_time_ns[0]},
                                       sw_sys_clk_period_ns[0]);
  sda_hold_cycles    = round_up_divide({sw_data_hold_time_ns[1], sw_data_hold_time_ns[0]},
                                       sw_sys_clk_period_ns[0]);
  start_setup_cycles = round_up_divide({sw_setup_start_time_ns[1], sw_setup_start_time_ns[0]},
                                       sw_sys_clk_period_ns[0]);
  start_hold_cycles  = round_up_divide({sw_hold_start_time_ns[1], sw_hold_start_time_ns[0]},
                                       sw_sys_clk_period_ns[0]);
  stop_setup_cycles  = round_up_divide({sw_setup_stop_time_ns[1], sw_setup_stop_time_ns[0]},
                                       sw_sys_clk_period_ns[0]);
  stop_hold_cycles   = round_up_divide({sw_hold_stop_time_ns[1], sw_hold_stop_time_ns[0]},
                                       sw_sys_clk_period_ns[0]);
  rise_cycles        = round_up_divide({sw_rise_time_ns[1], sw_rise_time_ns[0]},
                                       sw_sys_clk_period_ns[0]);
  fall_cycles        = round_up_divide({sw_fall_time_ns[1], sw_fall_time_ns[0]},
                                       sw_sys_clk_period_ns[0]);
endtask

function void top_chip_dv_i2c_device_tx_rx_vseq::fill_i2c_xfer_flds(i2c_item item,
                                                                    rw_e     dir,
                                                                    bus_op_e bus_op);
  item.addr     = (xfer_addr) ? device_addr0[0] : device_addr1[0];
  item.num_data = xfer_bytes[0];
  item.addr_ack = ACK;
  item.dir      = dir;
  item.bus_op   = bus_op;
  item.start    = 1;
  item.stop     = 1;

  // We don't need to fill data_ack_q for BusOpWrite, as N/Acking is the device's job.
  if (bus_op == BusOpRead) begin
    for (int unsigned i = 0; i < xfer_bytes[0]; i++) begin
      // The host acks every byte except the last one to terminate the transfer
      acknack_e ack_nack = (i == (xfer_bytes[0] - 1)) ? NACK : ACK;
      item.data_ack_q.push_back(ack_nack);
    end
  end
endfunction

function i2c_item top_chip_dv_i2c_device_tx_rx_vseq::assign_drv_type_and_wdata(drv_type_e drv_type,
                                                                              bit [7:0]  data);
  i2c_item item = i2c_item::type_id::create("item");
  item.drv_type = drv_type;
  item.wdata    = data;
  return item;
endfunction

function void top_chip_dv_i2c_device_tx_rx_vseq::conv_i2c_xfer_to_drv_type(ref i2c_item item_q[$],
                                                                           i2c_item     xfer);
  // Each transfer starts with a start condition (ignoring repeated start for now)
  if (xfer.start) item_q.push_back(assign_drv_type_and_wdata(HostStart, 'd0));

  // Send Address + Direction information
  item_q.push_back(assign_drv_type_and_wdata(HostData, (xfer.addr[6:0] << 1) | xfer.dir));

  for(int unsigned i = 0; i < xfer_bytes[0]; i++) begin
    case (xfer.bus_op)
      BusOpRead: begin
        drv_type_e ack_nack = (xfer.data_ack_q[i] == i2c_pkg::ACK) ? HostAck : HostNAck;
        item_q.push_back(assign_drv_type_and_wdata(ack_nack, '0));
      end
      BusOpWrite:
        // For write bytes, insert the data bytes in the data_q
        item_q.push_back(assign_drv_type_and_wdata(HostData, xfer.data_q[i]));
      default:;
    endcase
  end

  // Assumes that each transfer ends with a stop. Ignoring repeated start for now
  if (xfer.stop) item_q.push_back(assign_drv_type_and_wdata(HostStop, 'd0));
endfunction

task top_chip_dv_i2c_device_tx_rx_vseq::create_and_drive_i2c_xfer(i2c_item            item,
                                                                  rw_e                dir,
                                                                  bus_op_e            bus_op,
                                                                  i2c_target_base_seq host_seq);
  fill_i2c_xfer_flds(item, dir, bus_op);
  conv_i2c_xfer_to_drv_type(host_seq.req_q, item);

  // The host_seq pops the items from the front inserted in host_seq.req_q through
  // conv_i2c_xfer_to_drv_type() and sends those items to i2c_driver via the start_item() call.
  host_seq.start(p_sequencer.i2c_sqr);
endtask

task top_chip_dv_i2c_device_tx_rx_vseq::i2c_xfer();
  i2c_item xfer = i2c_item::type_id::create("xfer");
  i2c_target_base_seq host_seq = i2c_target_base_seq::type_id::create("host_seq");

  create_and_drive_i2c_xfer(xfer, READ, BusOpRead, host_seq);

  // De-allocate the xfer item in order to send a new transfer
  xfer = null;

  // Check if the agent received all the bytes
  if (cfg.m_i2c_agent_cfg.rcvd_rd_byte != xfer_bytes[0])
    `uvm_fatal(`gfn,
               $sformatf("Agent received %0d bytes but expecting %0d",
                         cfg.m_i2c_agent_cfg.rcvd_rd_byte,
                         xfer_bytes[0]))

  // The idea here is to write all the bytes previously read by the host.
  //
  // i2c_monitor has a port "controller_mode_rd_item_port" that contains the read transfer
  // information. It is connected with the analysis FIFO "i2c_rd_xfer_fifo". Once, the transfer is
  // finished, i2c_monitor writes that i2c_item to the controller_mode_rd_item_port. Check that this
  // item exist in the analysis FIFO i2c_rd_xfer_fifo.
  if (!p_sequencer.i2c_rd_xfer_fifo.used())
    `uvm_fatal(`gfn, "Agent didn't push the last read transfer in the FIFO")

  // Get the last transfer from the analysis FIFO
  p_sequencer.i2c_rd_xfer_fifo.get(xfer);

  // Now xfer contains the information involved in the last read transfer. The read bytes should be
  // saved in data_q. Those are going to be the data bytes written to the target in the write
  // transfer below.
  create_and_drive_i2c_xfer(xfer, WRITE, BusOpWrite, host_seq);
endtask

task top_chip_dv_i2c_device_tx_rx_vseq::body();
  // Configure the agent to be the Host
  cfg.m_i2c_agent_cfg.if_mode = Host;
  super.body();
  `DV_WAIT(cfg.sw_test_status_vif.sw_test_status == SwTestStatusInTest);

  configure_agent_timing();
  print_i2c_timing_cfg();

  // Wait until SW is done writing to the TX FIFO
  //
  // TODO: Remove when #600 is merged
  while (!tx_fifo_wr_done[0]) begin
    cfg.sys_clk_vif.wait_n_clks(1);
    sw_symbol_backdoor_read("tx_fifo_wr_done", tx_fifo_wr_done);
  end

  `uvm_info(`gfn, "Starting I2C Device TX-RX test", UVM_LOW)

  i2c_xfer();
endtask : body
