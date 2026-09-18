# Mailbox

The Mailbox is vendored from the PULP platform [`axi` repository][pulp axi] at revision [`a256a3b`][pulp hash].
The documentation for the hardware IP block is located [in the vendored HW directory tree][block doc].
The Mailbox connects two AXI4-Lite subordinate ports back to back over a pair of FIFOs, so data written on one port is read from the other, and raises a per-port interrupt on FIFO fill level or on an error.
Mocha instantiates it in [`top_chip_system.sv`][instantiation] with a `MailboxDepth` of 3, one port reached from the main crossbar and the other brought out of the chip as an external AXI port, each behind an `axi_to_axi_lite` converter.

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
| RTL           | CLKRST_CONNECTED           | Done   | Modules containing submodules checked: `axi_lite_mailbox` and `axi_lite_mailbox_slave`, both in `axi_lite_mailbox.sv`, which also declares the unused `axi_lite_mailbox_intf` wrapper. The submodules `fifo_v3` and `spill_register` take a clock and reset; `addr_decode` has neither and is confirmed to be purely combinational. The shared `common_cells` submodules are covered by their own upstream sign-offs and are not walked here.
| RTL           | IP_TOP                     | Done   | This module is defined in `axi_lite_mailbox.sv`. It has no core file of its own; it is compiled as part of the vendored `axi.core`.
| RTL           | IP_INSTANTIABLE            | Done   | It is instantiated in top chip system.
| RTL           | PHYSICAL_MACROS_DEFINED_80 | Done   | No memory macros or analogue components. The two mailbox FIFOs are flop-based `fifo_v3` instances.
| RTL           | FUNC_IMPLEMENTED           | Done   | All functionality already implemented.
| RTL           | ASSERT_KNOWN_ADDED         | Done   | Output assertions are [here][output asserts] and cover the interrupt and subordinate response signals, with the B and R payloads gated on their valid.
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
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[d1-commit]: https://github.com/lowRISC/mocha/commit/b6edc2ae5cdee9f1d4d1baa815921bb658c82613
[instantiation]: ../../hw/top_chip/rtl/top_chip_system.sv#L637
[output asserts]: ../../hw/vendor/pulp_axi/src/axi_lite_mailbox.sv#L191-L202
[lint waivers]: ../../hw/top_chip/lint/top_chip_system.vlt#L60-L70
[waivers issue]: https://github.com/lowRISC/mocha/issues/739