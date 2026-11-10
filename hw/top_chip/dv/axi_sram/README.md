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
The data and tag memories start from random contents, since their initial value is undefined, and the scoreboard only checks bytes and tags that have been written.

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

## Assertions

The verification plan's assertion items are carried by [`sva/axi_sram_assert.sv`][assert], which [`sva/axi_sram_bind.sv`][bind] binds into every `axi_sram` instance, so the block tb and the top-level build both carry it.
The bind reaches the tag signals by name, since they are internal to `axi_sram`.
The DUT's own output-known checks stay in the RTL.

| Plan item | Assertion |
| --- | --- |
| `sram_geometry` | `GeometryMatchesSpec_A`, `SramSizeMatchesSpec_A`, plus the RTL's own `TagRamCoversDataRam_A` and `SramSizeMatchesMap_A` |
| `partial_strobe_clears_tag` | `TagSetNeedsFullStrobe_A` |
| `burst_wrap` | `AwNo4kbCrossing_A`, `ArNo4kbCrossing_A` |
| `bounded_response` | `BValidBounded_A`, `RValidBounded_A` |
| `cap_both_ruser_set` | `CapReadRuserBeatsAgree_A` |
| `misaligned_read_clears_tag` | `NonCapReadHasNoTag_A` |

The response bounds are measured from the point the memory has everything it needs -- the last write beat, or the read request -- so they do not depend on how the manager paces the channels.
`CapReadRuserBeatsAgree_A` excludes a tag write landing between a capability read's two beats: the beats are separate memory accesses, and a write the manager has not ordered against the read may be seen by either of them.

## Not covered yet

The bridge in front of the memory, `axi_to_detailed_mem`, accepts one burst per direction: it holds `AxREADY` low until the burst in progress in that direction has been serviced.
It interleaves the read and the write beats on a single memory port, serving a single-beat write ahead of a read beat that is not the read's last, so a write can land inside a read burst of three or more beats.
`multiple_outstanding_transactions` therefore never has more than one burst per direction in flight, and `raw_war_same_region` races only single-beat accesses and capability bursts, not a longer read burst.
Both are recorded in the plan with that reason.

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
[assert]: ./sva/axi_sram_assert.sv
[bind]: ./sva/axi_sram_bind.sv
