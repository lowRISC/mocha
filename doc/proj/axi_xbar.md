# AXI crossbar

The AXI crossbar is vendored from the PULP platform [`axi` repository][pulp axi] at revision [`a256a3b`][pulp hash].
The documentation for the hardware IP block is located [in the vendored HW directory tree][block doc].
It is a fully connected AXI4 crossbar.
Mocha instantiates it in [`top_chip_system.sv`][instantiation] connecting two hosts to eight devices, with atomics disabled, and the address map that routes the ROM, SRAM, debug memory, mailbox, software-DV window, TileLink crossbar and the rest of the chip.

The rest of this document contains the design checklist for the AXI crossbar hardware IP block for the CHERI Mocha top.
For more details on the stages and the current state for each block, please refer to the [stages documentation][stages].

## Design sign-offs

### D1

The AXI crossbar used for D1 sign-off is the one vendored from the PULP platform at revision [`a256a3b`][pulp hash].
The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].
This sign-off is based on commit [`b597321`][d1-commit].

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | [AXI crossbar specification][block doc], covering the parameters, ports, address map and ordering rules.
| Documentation | CSR_DEFINED                | Done   | The crossbar has no registers; it is configured entirely by parameters and the address map input.
| RTL           | CLKRST_CONNECTED           | Done   | Modules containing submodules checked: `axi_xbar` in `axi_xbar.sv`, which also declares the unused `axi_xbar_intf` wrapper, and `axi_xbar_unmuxed.sv`. Their submodules `axi_mux`, `axi_demux`, `axi_err_slv` and `axi_multicut` all take a clock and reset; `addr_decode` is confirmed to be purely combinational. The shared `common_cells` and general `axi` submodules are covered by their own upstream sign-offs and are not walked here.
| RTL           | IP_TOP                     | Done   | This module is defined in `axi_xbar.sv`. It has no core file of its own; it is compiled as part of the vendored `axi.core`.
| RTL           | IP_INSTANTIABLE            | Done   | It is instantiated in top chip system.
| RTL           | PHYSICAL_MACROS_DEFINED_80 | Done   | No memory macros or analogue components. The request and response buffering is flop-based.
| RTL           | FUNC_IMPLEMENTED           | Done   | All functionality already implemented. Atomics are disabled at the instantiation.
| RTL           | ASSERT_KNOWN_ADDED         | Waived | The crossbar carries whatever the attached blocks drive, so the known checks on their outputs are sufficient and crossbar-level assertions would be redundant. Assertions were proposed and rejected on this basis in [pull request #734][assertions pr].
| Code Quality  | LINT_SETUP                 | Done   | Verilator lint target with `-Wall` in `top_chip_system.core`. The blanket PULP AXI waivers in [top_chip_system.vlt][lint waivers] cover this file, but the block produces no warnings with them disabled.

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

[block doc]: ../../hw/vendor/pulp_axi/doc/axi_xbar.md
[stages]: stages.md
[design stages]: stages.md#design-stages
[verification stages]: stages.md#verification-stages
[pulp axi]: https://github.com/pulp-platform/axi
[pulp hash]: https://github.com/pulp-platform/axi/tree/a256a3b86394fedf19e361047fccfdd7f6ef83e4
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[d1-commit]: https://github.com/lowRISC/mocha/commit/b5973217f704923917e7761f73df7dfcb8d0c345
[instantiation]: ../../hw/top_chip/rtl/top_chip_system.sv#L558
[assertions pr]: https://github.com/lowRISC/mocha/pull/734
[lint waivers]: ../../hw/top_chip/lint/top_chip_system.vlt#L60-L69
