# Mailbox

The Mailbox is vendored from the PULP platform [`axi` repository][pulp axi] at revision [`a256a3b`][pulp hash].
The documentation for the hardware IP block is located [in the vendored HW directory tree][block doc].
The Mailbox connects two AXI4-Lite subordinate ports back to back over a pair of FIFOs, so data written on one port is read from the other, and raises a per-port interrupt on FIFO fill level or on an error.
Only the main-port interrupt is consumed in Mocha: it reaches the PLIC as interrupt 11, while the external-port interrupt is brought out of the chip as `mailbox_ext_irq_o` and left unconnected at the Genesys 2 top.
Mocha instantiates it in [`top_chip_system.sv`][instantiation] with a `MailboxDepth` of 3, one port reached from the main crossbar and the other brought out of the chip as an external AXI port, each behind an `axi_to_axi_lite` converter.
The depth is final for D1; the `TODO: Tune me` comment at the instantiation is a note for later tuning, not an open design decision.
The block's RTL carries exactly one Mocha delta. [`0006_Add_Mailbox_Output_Assertions.patch`][assert patch] adds the output known assertions to `axi_lite_mailbox.sv` and `lowrisc:prim:assert` to `axi.core`.
[`0001_Primitives_from_lowRISC_used.patch`][prim patch] leaves `axi_lite_mailbox.sv` unmodified; it redirects the `common_cells` dependency in `axi.core` to the lowRISC wrappers, so the mailbox's `fifo_v3`, `spill_register` and `addr_decode` resolve to `hw/ip/common_cells`, and it removes the `benchs` fileset.
Upstream's own mailbox testbench, `test/tb_axi_lite_mailbox.sv`, is still in the tree but no fileset compiles it, and the `axi.core` `sim_lite_mailbox` target still references the removed fileset.

The rest of this document contains the design checklist for the Mailbox hardware IP block for the CHERI Mocha top.
For more details on the stages and the current state for each block, please refer to the [stages documentation][stages].

## Design sign-offs

### D1

The Mailbox used for D1 sign-off is the one at the vendored revision above.
The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].
This sign-off is based on commit [`b6edc2a`][d1-commit].

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | [Mailbox specification][block doc], covering the parameters, ports, register map and interrupt behaviour.
| Documentation | CSR_DEFINED                | Done   | The registers are defined in the [register address mapping][registers].
| RTL           | CLKRST_CONNECTED           | Done   | Modules containing submodules checked: `axi_lite_mailbox` and `axi_lite_mailbox_slave`, both in `axi_lite_mailbox.sv`, which also declares the unused `axi_lite_mailbox_intf` wrapper, and below them `fifo_v3` and `prim_fifo_sync`. `spill_register` and `prim_fifo_sync_cnt` take a clock and reset and instantiate nothing further in this configuration. `addr_decode` has neither and is confirmed to be purely combinational.
| RTL           | IP_TOP                     | Done   | This module is defined in `axi_lite_mailbox.sv`. It has no core file of its own; it is compiled as part of the vendored `axi.core`.
| RTL           | IP_INSTANTIABLE            | Done   | It is instantiated in top chip system.
| RTL           | PHYSICAL_MACROS_DEFINED_80 | Done   | No memory macros or analogue components. The two mailbox FIFOs are flop-based `fifo_v3` instances.
| RTL           | FUNC_IMPLEMENTED           | Done   | All functionality already implemented.
| RTL           | ASSERT_KNOWN_ADDED         | Done   | Output assertions are [here][output asserts], added by [`0006_Add_Mailbox_Output_Assertions.patch`][assert patch]. They cover the interrupt and subordinate response signals, with the B and R payloads gated on their valid.
| Code Quality  | LINT_SETUP                 | Done   | Verilator lint target with `-Wall` in `top_chip_system.core`. Nine unoptimisable-flat and two width-expansion warnings in the block are suppressed by the PULP AXI waivers in [top_chip_system.vlt][lint waivers]. They will be fixed in [issue #739][waivers issue].

### D2

*Checklist to be defined — see [stages.md][design stages].*

### D3

*Checklist to be defined — see [stages.md][design stages].*

## Verification sign-offs

### V1

*Not yet started — see [stages.md][verification stages].*

### V2

*Checklist to be defined — see [stages.md][verification stages].*

### V3

*Checklist to be defined — see [stages.md][verification stages].*

[block doc]: ../../hw/vendor/pulp_axi/doc/axi_lite_mailbox.md
[registers]: ../../hw/vendor/pulp_axi/doc/axi_lite_mailbox.md#register-address-mapping
[stages]: stages.md
[design stages]: stages.md#design-stages
[verification stages]: stages.md#verification-stages
[pulp axi]: https://github.com/pulp-platform/axi
[pulp hash]: https://github.com/pulp-platform/axi/tree/a256a3b86394fedf19e361047fccfdd7f6ef83e4
[prim patch]: ../../hw/vendor/patches/pulp_axi/0001_Primitives_from_lowRISC_used.patch
[assert patch]: ../../hw/vendor/patches/pulp_axi/0006_Add_Mailbox_Output_Assertions.patch
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[d1-commit]: https://github.com/lowRISC/mocha/commit/b6edc2ae5cdee9f1d4d1baa815921bb658c82613
[instantiation]: ../../hw/top_chip/rtl/top_chip_system.sv#L637
[output asserts]: ../../hw/vendor/pulp_axi/src/axi_lite_mailbox.sv#L191-L202
[lint waivers]: ../../hw/top_chip/lint/top_chip_system.vlt#L60-L69
[waivers issue]: https://github.com/lowRISC/mocha/issues/739
