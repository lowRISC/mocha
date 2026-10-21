<!--
Copyright lowRISC and contributors (COSMIC project).
Licensed under the Apache License, Version 2.0, see LICENSE for details.
SPDX-License-Identifier: Apache-2.0
-->

# AXI SRAM Verification

This environment verifies [`axi_sram`][axi_sram] at block level.
The SRAM holds a CHERI capability tag bit per 128-bit aligned region, carried on `WUSER` and returned on `RUSER`, so most of the effort here goes on when that tag is set, cleared and returned.

The verification plan is [`data/axi_sram_vplan.hjson`][vplan].
It is split between this block-level environment and the integration-level tests at [`hw/top_chip/dv`][top_chip_dv], which reach the SRAM through the crossbar.

## Testbench

[`block_tb/axi_sram_block_tb.sv`][block_tb] instantiates `axi_sram` alone.
A Manager-mode [`axi_vip_if`][axi_vip_if] drives the device port, so the `axi_mgr_agent` in [`env`][env] issues the traffic the CPU and the fabric would otherwise generate.
The data and tag memories are zeroed at time 0, because an X in the tag read-modify-write trips `prim_fifo_sync`'s `DataKnown_A`.

Checking is a behavioural reference model rather than a register model:

* [`axi_sram_ref_model.svh`][ref_model] models the data and tag memories, applying every write the monitor observes, with the tag rules from the SRAM specification in [`doc/ref/arch.md`][arch].
* [`axi_sram_scoreboard.svh`][scoreboard] subscribes to the agent monitor's `m_transaction_port` and compares every completed read against the model: response, data, and the `RUSER` tag bit, beat by beat.

Because the model is driven by observed traffic, a test only has to generate the accesses it cares about; the data and tag checking comes for free.

[`env/axi_sram_cov.sv`][cov] is a passive sampler on the same port, covering the tag write gating conditions and the `RUSER` a read returns.
The W and R channels carry no address, so it keeps small AW/AR attribute queues and attributes each beat to its governing request.

## Running

```bash
# One test
dvsim hw/top_chip/dv/axi_sram/block_tb/axi_sram_block_sim_cfg.hjson -i axi_sram_write_read

# The four-test smoke set, or every test in this cfg
dvsim hw/top_chip/dv/axi_sram/block_tb/axi_sram_block_sim_cfg.hjson -i smoke
dvsim hw/top_chip/dv/axi_sram/block_tb/axi_sram_block_sim_cfg.hjson -i block

# With functional coverage
dvsim hw/top_chip/dv/axi_sram/block_tb/axi_sram_block_sim_cfg.hjson -i block --cov
```

The cfg is part of the batch group in [`mocha_sim_cfgs.hjson`][mocha_sim_cfgs].

## Not covered yet

The bridge in front of the memory, `axi_to_detailed_mem`, accepts one burst per direction and arbitrates both onto a single memory port, so it is single-outstanding by construction: it holds `AxREADY` low until the burst in progress has been serviced.
`multiple_outstanding_transactions` and `raw_war_same_region` therefore issue their accesses concurrently but never achieve overlap, and no RAW/WAR hazard can arise.
Both are recorded in the plan with that reason; the tests are kept, since issuing them together and checking the settled result is the most the DUT allows.

`atomic_excluded` has no stimulus.
The plan asks for four ATOP encodings driven and answered with SLVERR, but `axi_if` carries no AWATOP and `axi_vip_if` drives `aw.atop` as zero, so a non-zero ATOP cannot be driven at all.
The item needs AWATOP support in the AXI agent first.

`backpressure` throttles the response side only.
The agent exposes READY timing on the B and R accepts, which the test randomises per transaction, but nothing delays the manager's own AW, W or AR VALID, so the plan's request-channel throttling needs that support in the agent first.

[axi_sram]: ../../rtl/axi_sram.sv
[arch]: ../../../../doc/ref/arch.md
[vplan]: ./data/axi_sram_vplan.hjson
[top_chip_dv]: ../README.md
[block_tb]: ./block_tb/axi_sram_block_tb.sv
[axi_vip_if]: ../../../ip/dv/axi_agent/axi_vip/axi_vip_if.sv
[env]: ./env
[ref_model]: ./env/axi_sram_ref_model.svh
[scoreboard]: ./env/axi_sram_scoreboard.svh
[cov]: ./env/axi_sram_cov.sv
[mocha_sim_cfgs]: ../mocha_sim_cfgs.hjson
