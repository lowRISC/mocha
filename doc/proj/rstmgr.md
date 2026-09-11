# Reset manager

The Reset manager in Mocha is generated with `ipgen` from the OpenTitan `rstmgr` IP template.
The documentation for the hardware IP block is its [theory of operation][theory], [register mapping][registers] and block [README][block doc].
The register mapping documentation and README are currently empty stubs but will be generated once `cmdgen` is imported, as part of [issue #706][cmdgen].
It generates the chip's reset tree, holds the software-controllable peripheral resets, records the cause of the last reset, and checks that each leaf reset actually takes effect.
The [Mocha configuration][ipconfig] declares `aon`, `io` and `main` clocks and the reset requests the power manager can raise.
The [vendor patches][patch] fix DV paths and the default simulator, correct the templates and adjust a cascade assertion; the logic is unchanged.

The rest of this document contains the design checklist for the Reset manager hardware IP block for the CHERI Mocha top.
For more details on the stages and the current state for each block, please refer to the [stages documentation][stages].

## Design sign-offs

### D1

The Reset manager used for D1 sign-off is generated from the OpenTitan template at revision [`bf4a2b2`][OpenTitan hash].
The D1 checklist rows were last updated upstream in [this pull request][OpenTitan D1 sign-off], which declares the block at D3; it is an ancestor of the vendored revision, so those are the rows Mocha inherits.
The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].
This sign-off is based on commit [`d918b3e`][d1-commit].

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | [Theory of operation][theory] and [programmer's guide][pguide].
| Documentation | CSR_DEFINED                | Done   | Registers are defined in [rstmgr.hjson][csrs] and generated into `rstmgr_reg_pkg.sv` and `rstmgr_reg_top.sv`.
| RTL           | CLKRST_CONNECTED           | Done   | Modules containing submodules checked: `rstmgr.sv`, `rstmgr_ctrl.sv`, `rstmgr_por.sv`, `rstmgr_leaf_rst.sv`, `rstmgr_cnsty_chk.sv` and `rstmgr_reg_top.sv`. Modules without clocks and resets are confirmed to be purely combinational: `prim_subreg_ext`, `tlul_cmd_intg_chk` and `tlul_rsp_intg_gen`. The shared `prim_*` and `tlul_*` submodules are covered by their own OpenTitan sign-offs and are not walked here.
| RTL           | IP_TOP                     | Done   | This module is defined in `rstmgr.sv`.
| RTL           | IP_INSTANTIABLE            | Done   | It is instantiated in top chip system.
| RTL           | PHYSICAL_MACROS_DEFINED_80 | Done   | No memory macros or analogue components.
| RTL           | FUNC_IMPLEMENTED           | Done   | All functionality already implemented.
| RTL           | ASSERT_KNOWN_ADDED         | Done   | Output assertions are [here][output asserts] and cover every output.
| Code Quality  | LINT_SETUP                 | Done   | Verilator lint target with `-Wall` in `rstmgr.core` and in the top. One synchronous-versus-asynchronous reset warning on the leaf reset output [is waived][lint waivers].

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

[block doc]: ../../hw/top_chip/ip_autogen/rstmgr/README.md
[stages]: stages.md
[design stages]: stages.md#design-stages
[verification stages]: stages.md#verification-stages
[OpenTitan hash]: https://github.com/lowRISC/opentitan/tree/bf4a2b24e41742151cfce9c4041e959a3ba76ca3
[OpenTitan D1 sign-off]: https://github.com/lowRISC/opentitan/pull/24164
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[d1-commit]: https://github.com/lowRISC/mocha/commit/d918b3ef1b80febeccbae3c9d7d8b30edf8a1186
[theory]: ../../hw/top_chip/ip_autogen/rstmgr/doc/theory_of_operation.md
[pguide]: ../../hw/top_chip/ip_autogen/rstmgr/doc/programmers_guide.md
[registers]: ../../hw/top_chip/ip_autogen/rstmgr/doc/registers.md
[csrs]: ../../hw/top_chip/ip_autogen/rstmgr/data/rstmgr.hjson
[ipconfig]: ../../hw/top_chip/data/rstmgr_cfg.hjson
[cmdgen]: https://github.com/lowRISC/mocha/issues/706
[output asserts]: ../../hw/top_chip/ip_autogen/rstmgr/rtl/rstmgr.sv#L698-L704
[lint waivers]: ../../hw/top_chip/lint/top_chip_system.vlt
[patch]: ../../hw/vendor/patches/lowrisc_ip/rstmgr
