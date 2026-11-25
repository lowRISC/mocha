<!--
Copyright lowRISC and contributors (COSMIC project).
Licensed under the Apache License, Version 2.0, see LICENSE for details.
SPDX-License-Identifier: Apache-2.0
-->

# AXI SRAM Verification

This environment verifies [`axi_sram`][axi_sram] at block level.
The SRAM holds a CHERI capability tag bit per 128-bit aligned region, carried on `WUSER` and returned on `RUSER`, so most of the effort here goes on when that tag is set, cleared and returned.

The verification plan is [`../data/axi_sram_vplan.hjson`][vplan].
It is split between this block-level environment and the integration-level tests at [`hw/top_chip/dv`][top_chip_dv], which reach the SRAM through the crossbar.

## Testbench

[`tb/tb.sv`][tb] instantiates `axi_sram` alone.
A Manager-mode [`axi_vip_if`][axi_vip_if] drives the device port, so the `axi_mgr_agent` in [`env`][env] issues the traffic the CPU and the fabric would otherwise generate.
The data and tag memories start from random contents, since their initial value is undefined, and the scoreboard only checks bytes and tags that have been written.

Checking is a behavioural reference model rather than a register model:

* [`axi_sram_ref_model.svh`][ref_model] models the data and tag memories, applying every write the monitor observes, with the tag rules from the SRAM specification in [`doc/ref/arch.md`][arch].
* [`axi_sram_scoreboard.svh`][scoreboard] subscribes to the agent monitor's `m_transaction_port` and compares every completed read against the model: response, data, and the `RUSER` tag bit, beat by beat.

Because the model is driven by observed traffic, a test only has to generate the accesses it cares about; the data and tag checking comes for free.

[`axi_sram_env_cov.svh`][cov] subscribes to the same monitor port when `+en_cov` is set, covering the tag write gating conditions and the `RUSER` a read returns.

## Running

```bash
# One test
dvsim hw/ip/axi_sram/dv/axi_sram_sim_cfg.hjson -i axi_sram_write_read

# The four-test smoke set, or every test in this cfg
dvsim hw/ip/axi_sram/dv/axi_sram_sim_cfg.hjson -i smoke
dvsim hw/ip/axi_sram/dv/axi_sram_sim_cfg.hjson -i block

# With functional coverage
dvsim hw/ip/axi_sram/dv/axi_sram_sim_cfg.hjson -i block --cov
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

[axi_sram]: ../../../top_chip/rtl/axi_sram.sv
[arch]: ../../../../doc/ref/arch.md
[vplan]: ../data/axi_sram_vplan.hjson
[top_chip_dv]: ../../../top_chip/dv/README.md
[tb]: ./tb/tb.sv
[axi_vip_if]: ../../dv/axi_agent/axi_vip/axi_vip_if.sv
[env]: ./env
[ref_model]: ./env/axi_sram_ref_model.svh
[scoreboard]: ./env/axi_sram_scoreboard.svh
[cov]: ./env/axi_sram_env_cov.svh
[mocha_sim_cfgs]: ../../../top_chip/dv/mocha_sim_cfgs.hjson
[assert]: ./sva/axi_sram_assert.sv
[bind]: ./sva/axi_sram_bind.sv
