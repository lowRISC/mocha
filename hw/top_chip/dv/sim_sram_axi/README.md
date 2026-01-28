<!--
Copyright lowRISC contributors (COSMIC project).
Licensed under the Apache License, Version 2.0, see LICENSE for details.
SPDX-License-Identifier: Apache-2.0
-->

# Simulation SRAM AXI

The `sim_sram_axi_sink` module intercepts an outbound AXI interface to carve out a chunk of "fake" memory used for simulation purposes only.
This chunk of memory must not overlap with any device on the system address map - it must be an invalid address range from the system's perspective.

It has 4 interfaces - clock, reset, input AXI interface from the CVA6 CPU (`cpu_req_i` and `cpu_resp_o`) and the output AXI interface to the AXI Crossbar (`xbar_req_o` and `xbar_resp_i`).
It instantiates a [1:2 AXI Demultiplexer](../../../vendor/pulp_axi/doc/axi_demux.md) to split the incoming AXI access into two.
One of the outputs of the socket is sinked within the module while the other is returned back.

If the user chooses to instantiate an actual SRAM instance (`InstantiateSram=1`), the sinked AXI interface is connected to the AXI to SRAM adapter `axi_to_mem` which converts the AXI access into a SRAM access.
The [technology-independent](../../../ip/prim/README.md) `prim_ram_1p` module is used for instantiating the memory.

![Block Diagram](./doc/sim_sram_axi.svg)

This module is not meant to be synthesized.
Though it is written with the synthesizable subset of SystemVerilog to be Verilator-friendly, it creates a simulation-only "hole" in the memory map.

The most typical usecase for this module is for a SW test running on an embedded CPU in the design to be able to exchange information with the testbench.
In DV, this is envisioned to be used for the following purposes:
- Write the status of the SW test.
- Use as a SW logging device (bypassing slow UART).
- Write the output of an operation.
- Signal an event to the UVM environment.

These usecases apply to Verilator as well.
However, at this time, the Verilator based simulations rely on the on-device UART for logging.

This module must be instantiated before any XBAR / bus fabric element in the design which can return an error response when it sees an access to an invalid address range.
Ideally, it should be placed as close to the CPU (or equivalent) as possible to reduce the simulation time.

## Customizations

`sim_sram_axi_sink` exposes the following parameters:

- `InstantiateSram` (default: 0):

  Controls whether to instantiate the SRAM or not.
  The most typical (and recommended) operating mode is for the SW test to only write data to this SRAM, to make it portable across various simulation platforms (DV, Verilator, FPGA etc.).
  The testbench can simply probe the sinked output of the socket to monitor writes to specific addresses within this range.
  So, in reality, the actual SRAM instance is not needed for most cases.

  However, it does enable the possibility of having a testbench driven SW test control (the SW test can read the contents of the SRAM to know how to proceed) for tests that are custom written for a particular simulation platform.
  Enabling this parameter (`1`) allows the SW test to *read* back data, enabling handshaking between the SW and the testbench without using any on-chip resources. This is particularly useful for Verilator or FPGA-based emulation where UVM monitoring is not available.

- `SramDepth` (default: 8):

  Depth of the SRAM in bus words.

- `ErrOnRead` (default: 1):

  If the SW test reads from the SRAM, trigger an assertion error. This ensures the SW treats this region as "Write-Only" logging memory, improving portability to platforms where the Sim SRAM does not exist.

## Integration and Verification Interfaces

The `sim_sram_axi_sink` serves as the physical anchor for Verification Interfaces that sniff the traffic.

In addition, the module instantiates the `sim_sram_axi_if` interface to allow the testbench to control the `start_addr` and the `sw_dv_size` of the SRAM (defaults to 0) at run-time by hierarchically referencing them, e.g.:
```systemverilog
  // In top level testbench which instantiates the `sim_sram_axi_sink`:
  initial tb.dut.u_sim_sram.u_sim_sram_if.start_addr = 32'h3000_0000;
  initial tb.dut.u_sim_sram.u_sim_sram_if.sw_dv_size = 32'h0000_0080;
```

The module instantiates `sim_sram_axi_if`, which exposes `req` and `resp` signals capturing the redirected AXI transactions.
These signals are used to generate the `wr_valid` signal, qualifying valid AXI write accesses made to the simulation SRAM range.

In the Testbench Top (`tb.sv`), higher-level verification interfaces are `bind`-ed to this signal and their virtual handle is added into the `uvm_config_db`:
1.  **`sw_test_status_if`**: Monitors writes to `SW_DV_TEST_STATUS_ADDR` to detect if the test Passed or Failed.
2.  **`sw_logger_if`**: Monitors writes to `SW_DV_LOG_ADDR` to capture `printf` characters and display them in the simulation log.

## Usage

This module needs to be instantiated on an existing outbound AXI connection, possibly deep in an existing design hierarchy while also abiding by these guidelines:
- Design sources must not depend on simulation components.
- Design sources must not directly instantiate simulation components, even with `ifdefs`.
- Synthesis of the design must not disturbed whatsoever.
- We must be able to run simulations with Verilator (which prevents us from using forces for example).

One way of achieving this is by disconnecting an outbound AXI interface in the design source where `sim_sram_axi_sink` needs to be inserted.
The disconnection must be made in the desired design block ONLY if `` `SYNTHESIS`` is NOT defined and a special macro (user's choice on the name) is defined for simulations.

The sim_sram_axi_sink is always instantiated in the testbench.
The connection method changes based on the simulation mode:

- Verilator (`` `INST_SIM_SRAM`` is defined):
The TB connects to the DUT's internal signals via hierarchical references (assign).
Since the RTL connection was "cut" (see above), there is no contention, and force is not required.

- UVM (`` `INST_SIM_SRAM`` is **NOT** defined):
The RTL connection is intact.
The TB uses force statements to override the internal wires at runtime, effectively inserting the sink without modifying the compiled RTL logic.
