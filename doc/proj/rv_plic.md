# PLIC

The PLIC in Mocha is generated with `ipgen` from the OpenTitan `rv_plic` IP template.
The documentation for the hardware IP block is its [theory of operation][theory], [programmer's guide][pguide] and block [README][block doc].
It is a RISC-V platform-level interrupt controller: it collects the peripheral interrupt lines, applies a per-source priority and a per-target threshold, and raises the external interrupt to the core.
The block has no generated register mapping document; the registers are described in [rv_plic.hjson][csrs] and will be rendered once cmdgen is imported, as part of [issue #706][cmdgen].
The [vendor patches][patch] adjust the context interrupt enable stride and add the missing alert output known assertion; no datapath logic is changed.

The rest of this document contains the design checklist for the PLIC hardware IP block for the CHERI Mocha top.
For more details on the stages and the current state for each block, please refer to the [stages documentation][stages].

## Design sign-offs

### D1

The PLIC used for D1 sign-off is generated from the OpenTitan template at revision [`bf4a2b2`][OpenTitan hash], where it reached D2 in [this pull request][OpenTitan sign-off].
The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].
This sign-off is based on commit [`272c57d`][d1-commit].

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | [Theory of operation][theory] and [programmer's guide][pguide].
| Documentation | CSR_DEFINED                | Done   | Registers are defined in [rv_plic.hjson][csrs] and generated into `rv_plic_reg_pkg.sv` and `rv_plic_reg_top.sv`.
| RTL           | CLKRST_CONNECTED           | Done   | Modules containing submodules checked: `rv_plic.sv`, `rv_plic_target.sv` and `rv_plic_reg_top.sv`. Modules without clocks and resets are confirmed to be purely combinational: `prim_subreg_ext`, `tlul_cmd_intg_chk` and `tlul_rsp_intg_gen`. The shared `prim_*` and `tlul_*` submodules are covered by their own OpenTitan sign-offs and are not walked here.
| RTL           | IP_TOP                     | Done   | This module is defined in `rv_plic.sv`.
| RTL           | IP_INSTANTIABLE            | Done   | It is instantiated in top chip system.
| RTL           | PHYSICAL_MACROS_DEFINED_80 | Done   | No memory macros or analogue components.
| RTL           | FUNC_IMPLEMENTED           | Done   | All functionality already implemented.
| RTL           | ASSERT_KNOWN_ADDED         | Done   | Output assertions are [here][output asserts] and cover every output.
| Code Quality  | LINT_SETUP                 | Done   | Verilator lint target with `-Wall` in `rv_plic.core` and in the top. The block lints clean with no warnings in its own RTL.

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

[block doc]: ../../hw/top_chip/ip_autogen/rv_plic/README.md
[stages]: stages.md
[design stages]: stages.md#design-stages
[verification stages]: stages.md#verification-stages
[OpenTitan hash]: https://github.com/lowRISC/opentitan/tree/bf4a2b24e41742151cfce9c4041e959a3ba76ca3
[OpenTitan sign-off]: https://github.com/lowRISC/opentitan/pull/1480
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[d1-commit]: https://github.com/lowRISC/mocha/commit/272c57d8d91556f7c7889123c5da3bcf51dd8345
[theory]: ../../hw/top_chip/ip_autogen/rv_plic/doc/theory_of_operation.md
[pguide]: ../../hw/top_chip/ip_autogen/rv_plic/doc/programmers_guide.md
[csrs]: ../../hw/top_chip/ip_autogen/rv_plic/data/rv_plic.hjson
[cmdgen]: https://github.com/lowRISC/mocha/issues/706
[output asserts]: ../../hw/top_chip/ip_autogen/rv_plic/rtl/rv_plic.sv#L276-L284
[patch]: ../../hw/vendor/patches/lowrisc_ip/rv_plic
