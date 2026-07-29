// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/*
Module: bus
Author: Taken from lowRISC Ibex

-------------------------------------------------------------------------------
    DESCRIPTION
-------------------------------------------------------------------------------
Simple memory interface crossbar.
Known issue: does not support wait states. This is fine for now.

-------------------------------------------------------------------------------
    TESTS
-------------------------------------------------------------------------------
There are no dedicated tests for this module.

-------------------------------------------------------------------------------
    INSTANTIATION TEMPLATE
-------------------------------------------------------------------------------
  bus #(
      .NrDevices     (),
      .NrHosts       (),
      .DataWidth     (),
      .AddressWidth  ()
  ) bus_inst (
      .clk_i,
      .rst_ni,

      .host_req_i            (),
      .host_addr_i           (),
      .host_we_i             (),
      .host_be_i             (),
      .host_wdata_i          (),
      .host_rvalid_o         (),
      .host_gnt_o            (),
      .host_rdata_o          (),
      .host_err_o            (),

      .device_req_o          (),
      .device_addr_o         (),
      .device_we_o           (),
      .device_be_o           (),
      .device_wdata_o        (),
      .device_gnt_i          (),
      .device_rdata_i        (),
      .device_err_i          (),

      // Example memory map definition for 4 devices is shown below
      //                         CSR Address space \/     TX buffer address space \/    RX buffer address space \/   RX metadata address space \/
      .cfg_device_addr_base  ({  64'h0000_0000_0000_0800  ,   64'h0000_0000_0000_1000  ,   64'h0000_0000_0000_4000  ,   64'h0000_0000_0000_6000      }),
      .cfg_device_addr_mask  ({~(64'h0000_0000_0000_007F) , ~(64'h0000_0000_0000_07FF) , ~(64'h0000_0000_0000_1FFF) , ~(64'h0000_0000_0000_003F)     }),
      .device_rvalid_i       ()
  );

*/

// TODO fix this bus:
//  - support pipelining
//  - support wait states
//  - remove option for multiple hosts

`include "prim_assert.sv"

module bus #(
  parameter int NrDevices    = 1,
  parameter int NrHosts      = 1,
  parameter int DataWidth    = 32,
  parameter int AddressWidth = 32
) (
  input                           clk_i,
  input                           rst_ni,

  // Hosts
  input                           host_req_i    [NrHosts],
  output logic                    host_gnt_o    [NrHosts],

  input        [AddressWidth-1:0] host_addr_i   [NrHosts],
  input                           host_we_i     [NrHosts],
  input        [ DataWidth/8-1:0] host_be_i     [NrHosts],
  input        [   DataWidth-1:0] host_wdata_i  [NrHosts],
  output logic                    host_rvalid_o [NrHosts],
  output logic [   DataWidth-1:0] host_rdata_o  [NrHosts],
  output logic                    host_err_o    [NrHosts],

  // Devices
  output logic                    device_req_o    [NrDevices],

  output logic [AddressWidth-1:0] device_addr_o   [NrDevices],
  output logic                    device_we_o     [NrDevices],
  output logic [ DataWidth/8-1:0] device_be_o     [NrDevices],
  output logic [   DataWidth-1:0] device_wdata_o  [NrDevices],
  input                           device_rvalid_i [NrDevices],
  input        [   DataWidth-1:0] device_rdata_i  [NrDevices],
  input                           device_gnt_i    [NrDevices],
  input                           device_err_i    [NrDevices],

  // Device address map
  input        [AddressWidth-1:0] cfg_device_addr_base [NrDevices],
  input        [AddressWidth-1:0] cfg_device_addr_mask [NrDevices]
);

  localparam int unsigned NumBitsHostSel = NrHosts > 1 ? $clog2(NrHosts) : 1;
  localparam int unsigned NumBitsDeviceSel = NrDevices > 1 ? $clog2(NrDevices) : 1;

  // Wait states are currently not supported
  for (genvar i = 0; i < NrDevices; i++) begin : gen_device_gnt_check
    logic unused;
    assign unused = device_gnt_i[i];
    `ASSERT(BusNoWaitStates_A, ~device_req_o[i] | device_gnt_i[i]);
  end

  logic host_sel_valid;
  logic device_sel_valid;
  logic decode_err_resp;

  logic [NumBitsHostSel-1:0] host_sel_req, host_sel_resp;
  logic [NumBitsDeviceSel-1:0] device_sel_req, device_sel_resp;

  // Host select priority arbiter
  always_comb begin
    host_sel_valid = 1'b0;
    host_sel_req = '0;
    for (integer host = NrHosts - 1; host >= 0; host = host - 1) begin
      if (host_req_i[host]) begin
        host_sel_valid = 1'b1;
        host_sel_req = NumBitsHostSel'(host);
      end
    end
  end

  // Device select
  always_comb begin
    device_sel_valid = 1'b0;
    device_sel_req = '0;
    for (integer device = 0; device < NrDevices; device = device + 1) begin
      if ((host_addr_i[host_sel_req] & cfg_device_addr_mask[device])
          == cfg_device_addr_base[device]) begin
        device_sel_valid = 1'b1;
        device_sel_req = NumBitsDeviceSel'(device);
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      host_sel_resp <= '0;
      device_sel_resp <= '0;
      decode_err_resp <= 1'b0;
    end else begin
      // Responses are always expected 1 cycle after the request
      device_sel_resp <= device_sel_req;
      host_sel_resp <= host_sel_req;
      // Decode failed; no device matched?
      decode_err_resp <= host_sel_valid & !device_sel_valid;
    end
  end

  always_comb begin
    for (integer device = 0; device < NrDevices; device = device + 1) begin
      if (device_sel_valid && NumBitsDeviceSel'(device) == device_sel_req) begin
        device_req_o[device]   = host_req_i[host_sel_req];
        device_we_o[device]    = host_we_i[host_sel_req];
        device_addr_o[device]  = host_addr_i[host_sel_req];
        device_wdata_o[device] = host_wdata_i[host_sel_req];
        device_be_o[device]    = host_be_i[host_sel_req];
      end else begin
        device_req_o[device]   = 1'b0;
        device_we_o[device]    = 1'b0;
        device_addr_o[device]  = 'b0;
        device_wdata_o[device] = 'b0;
        device_be_o[device]    = 'b0;
      end
    end
  end

  always_comb begin
    for (integer host = 0; host < NrHosts; host = host + 1) begin
      host_gnt_o[host] = 1'b0;
      if (NumBitsHostSel'(host) == host_sel_resp) begin
        host_rvalid_o[host] = device_rvalid_i[device_sel_resp] | decode_err_resp;
        host_err_o[host]    = device_err_i[device_sel_resp]    | decode_err_resp;
        host_rdata_o[host]  = device_rdata_i[device_sel_resp];
      end else begin
        host_rvalid_o[host] = 1'b0;
        host_err_o[host]    = 1'b0;
        host_rdata_o[host]  = 'b0;
      end
    end
    host_gnt_o[host_sel_req] = host_req_i[host_sel_req];
  end
endmodule
