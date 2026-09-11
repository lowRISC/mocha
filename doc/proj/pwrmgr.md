# Power manager

The Power manager in Mocha is generated with `ipgen` from the OpenTitan `pwrmgr` IP template.
The documentation for the hardware IP block is its [theory of operation][theory], [register mapping][registers] and block [README][block doc].
The register mapping documentation is currently an empty stub but it will be generated once `cmdgen` is imported, as part of [issue #706][cmdgen].
It sequences the chip's power, clock and reset resources through cold boot, low power entry and exit, and reset, and releases the CPU once the ROM integrity check has passed.
The [Mocha configuration][ipconfig] declares one external wakeup and the main power glitch, escalation, non-debug-module and external peripheral reset requests, with `main` and `io` as the source clocks.
The [vendor patches][patch] add the Mocha fast-to-slow clock ratio, fix DV paths and the default simulator, follow the single-field reset status and enable registers of the Mocha configuration, and replace hard-coded reset request indices with the generated parameters; the logic is unchanged.

The rest of this document contains the design checklist for the Power manager hardware IP block for the CHERI Mocha top.
For more details on the stages and the current state for each block, please refer to the [stages documentation][stages].

## Design sign-offs

### D1

The Power manager used for D1 sign-off is generated from the OpenTitan template at revision [`bf4a2b2`][OpenTitan hash].
The D1 checklist rows were last updated upstream in [this pull request][OpenTitan D1 sign-off], which declares the block at D3; it is an ancestor of the vendored revision, so those are the rows Mocha inherits.
The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].
This sign-off is based on commit [`5d7a249`][d1-commit].

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | [Theory of operation][theory] and [programmer's guide][pguide].
| Documentation | CSR_DEFINED                | Done   | Registers are defined in [pwrmgr.hjson][csrs] and generated into `pwrmgr_reg_pkg.sv` and `pwrmgr_reg_top.sv`.
| RTL           | CLKRST_CONNECTED           | Done   | Modules containing submodules checked: `pwrmgr.sv`, `pwrmgr_fsm.sv`, `pwrmgr_slow_fsm.sv`, `pwrmgr_cdc.sv` and `pwrmgr_reg_top.sv`. Modules without clocks and resets are confirmed to be purely combinational: `prim_buf`, `prim_subreg_ext`, `tlul_cmd_intg_chk` and `tlul_rsp_intg_gen`. The shared `prim_*` and `tlul_*` submodules are covered by their own OpenTitan sign-offs and are not walked here.
| RTL           | IP_TOP                     | Done   | This module is defined in `pwrmgr.sv`.
| RTL           | IP_INSTANTIABLE            | Done   | It is instantiated in top chip system.
| RTL           | PHYSICAL_MACROS_DEFINED_80 | Done   | No memory macros or analogue components. The AST interface is tied to its defaults at the top.
| RTL           | FUNC_IMPLEMENTED           | Done   | All functionality already implemented. The wakeup and peripheral reset request inputs are tied off at the top, so low power entry and exit are exercised only at block level.
| RTL           | ASSERT_KNOWN_ADDED         | Done   | Output assertions are [here][output asserts] and cover every output.
| Code Quality  | LINT_SETUP                 | Done   | Verilator lint target with `-Wall` in `pwrmgr.core` and in the top. The block lints clean with no warnings in its own RTL.

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

[block doc]: ../../hw/top_chip/ip_autogen/pwrmgr/README.md
[stages]: stages.md
[design stages]: stages.md#design-stages
[verification stages]: stages.md#verification-stages
[OpenTitan hash]: https://github.com/lowRISC/opentitan/tree/bf4a2b24e41742151cfce9c4041e959a3ba76ca3
[OpenTitan D1 sign-off]: https://github.com/lowRISC/opentitan/pull/24191
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[d1-commit]: https://github.com/lowRISC/mocha/commit/5d7a249ac6caa60464ea64192ed9e418292edfb6
[theory]: ../../hw/top_chip/ip_autogen/pwrmgr/doc/theory_of_operation.md
[pguide]: ../../hw/top_chip/ip_autogen/pwrmgr/doc/programmers_guide.md
[registers]: ../../hw/top_chip/ip_autogen/pwrmgr/doc/registers.md
[csrs]: ../../hw/top_chip/ip_autogen/pwrmgr/data/pwrmgr.hjson
[ipconfig]: ../../hw/top_chip/data/pwrmgr_cfg.hjson
[cmdgen]: https://github.com/lowRISC/mocha/issues/706
[output asserts]: ../../hw/top_chip/ip_autogen/pwrmgr/rtl/pwrmgr.sv#L703-L715
[patch]: ../../hw/vendor/patches/lowrisc_ip/pwrmgr
