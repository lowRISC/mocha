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

*Checklist to be defined - see [stages.md][design stages].*

### D3

*Checklist to be defined - see [stages.md][design stages].*

## Verification sign-offs

### V1

All checklist items refer to the [V1 verification sign-off checklist][V1 checklist].
This sign-off is based on commit [`5d7a249`][v1-commit].

| Type          | Item                               | Status | Note/Collaterals |
|---------------|------------------------------------|--------|------------------|
| Documentation | DV_DOC_DRAFT_COMPLETED             | Done   | [Power manager DV document][] describes the goals, testbench architecture, stimulus, coverage, and checking strategy. It is template text that has not been regenerated for Mocha: it lists the six Earlgrey wakeups rather than the single `ext_wkup_req`, and eight of its links point at a `top_mocha` path in the OpenTitan repository that does not exist. Acceptable as a V1 draft. Tracked by [issue #751][dv readme issue] for V2 |
| Documentation | TESTPLAN_COMPLETED                 | Done   | [Power manager testplan][] defines the V1 smoke test and post-V1 wakeup, clock control, low power abort, reset, power glitch and stress testpoints |
| Testbench     | TB_TOP_CREATED                     | Done   | [tb.sv][] instantiates the four clocks, TileLink, power manager, interrupt, alert and escalation interfaces along with the power manager DUT |
| Testbench     | PRELIMINARY_ASSERTION_CHECKS_ADDED | Done   | [pwrmgr_bind.sv][] binds the TLUL protocol, CSR, clock enable and clock manager handshake assertions, and [pwrmgr_unit_only_bind.sv][] the reset manager handshake assertions; the power manager RTL checks that outputs are known after reset |
| Integration   | PRE_VERIFIED_SUB_MODULES_V1        | Waived | The Power manager and its primitive submodules (`prim_intr_hw`, `prim_subreg`, etc.) and TileLink adapters (`tlul_adapter_reg`, `tlul_cmd_intg_chk`, etc.) are generated from the OpenTitan template, where the block reached V2S ([OpenTitan power manager checklist][]) |
| Review        | DESIGN_SPEC_REVIEWED               | Waived | The specification was reviewed through the OpenTitan sign-off process; the Mocha wakeup, reset request and source clock configuration has not had a separate review |
| Review        | TESTPLAN_REVIEWED                  | Done   | The generated [OpenTitan power manager checklist][] records the testplan review as complete upstream. The [Power manager testplan][] is identical to the one in `ip_templates/pwrmgr` and has not been regenerated for Mocha: its V1 testpoints, `smoke` and the imported CSR testpoints, apply as written, but the V2 `control_clks` testpoint describes a usb clock that Mocha does not have, and no testpoint covers the single `ext_wkup_req` wakeup or the `rst_req_external` reset request. Those gaps are out of V1 scope and must be closed before V2 |
| Review        | STD_TEST_CATEGORIES_PLANNED        | Done   | Reset, escalation, main power glitch, invalid state and stress tests are covered in the [Power manager testplan][]; debug, power and performance are N/A |
| Simulation    | SIM_TB_ENV_CREATED                 | Done   | CIP-based UVM environment with TL agent and scoreboard |
| Tests         | SIM_SMOKE_TEST_PASSING             | Done   | `pwrmgr_smoke`: 50/50 passed with Xcelium on September 30, 2026 at commit `5d7a249` |
| Regression    | SIM_SMOKE_REGRESSION_SETUP         | Done   | `smoke` regression in `pwrmgr_sim_cfg.hjson` selects `pwrmgr_smoke`; the aggregate Mocha config imports the power manager simulation config |
| Regression    | SIM_NIGHTLY_REGRESSION_SETUP       | Done   | The Power manager is included in `mocha_sim_cfgs.hjson`, so it runs as part of the aggregate nightly regression; results are published on the [COSMIC reports dashboard][] |
| Coverage      | SIM_COVERAGE_MODEL_ADDED           | Done   | Block-level coverage is in `pwrmgr_env_cov.sv` |
| Tests         | FPV_MAIN_ASSERTIONS_PROVEN         | N/A    | This V1 sign-off uses simulation; TLUL and CSR assertions are enabled in the simulation testbench |
| Regression    | FPV_REGRESSION_SETUP               | N/A    | No Power manager FPV regression is configured in Mocha |

### V2

*Checklist to be defined - see [stages.md][verification stages].*

### V3

*Checklist to be defined - see [stages.md][verification stages].*

[block doc]: ../../hw/top_chip/ip_autogen/pwrmgr/README.md
[stages]: stages.md
[design stages]: stages.md#hardware-ip-block-design-stages
[verification stages]: stages.md#hardware-ip-block-verification-stages
[OpenTitan hash]: https://github.com/lowRISC/opentitan/tree/bf4a2b24e41742151cfce9c4041e959a3ba76ca3
[OpenTitan D1 sign-off]: https://github.com/lowRISC/opentitan/pull/24191
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[d1-commit]: https://github.com/lowRISC/mocha/commit/5d7a249ac6caa60464ea64192ed9e418292edfb6
[V1 checklist]: stages.md#v1-verification-sign-off-checklist
[v1-commit]: https://github.com/lowRISC/mocha/commit/5d7a249ac6caa60464ea64192ed9e418292edfb6
[theory]: ../../hw/top_chip/ip_autogen/pwrmgr/doc/theory_of_operation.md
[pguide]: ../../hw/top_chip/ip_autogen/pwrmgr/doc/programmers_guide.md
[registers]: ../../hw/top_chip/ip_autogen/pwrmgr/doc/registers.md
[csrs]: ../../hw/top_chip/ip_autogen/pwrmgr/data/pwrmgr.hjson
[ipconfig]: ../../hw/top_chip/data/pwrmgr_cfg.hjson
[cmdgen]: https://github.com/lowRISC/mocha/issues/706
[dv readme issue]: https://github.com/lowRISC/mocha/issues/751
[output asserts]: https://github.com/lowRISC/mocha/blob/5d7a249ac6caa60464ea64192ed9e418292edfb6/hw/top_chip/ip_autogen/pwrmgr/rtl/pwrmgr.sv#L703-L715
[patch]: ../../hw/vendor/patches/lowrisc_ip/pwrmgr
[Power manager DV document]: ../../hw/top_chip/ip_autogen/pwrmgr/dv/README.md
[Power manager testplan]: ../../hw/top_chip/ip_autogen/pwrmgr/data/pwrmgr_testplan.hjson
[tb.sv]: ../../hw/top_chip/ip_autogen/pwrmgr/dv/tb.sv
[pwrmgr_bind.sv]: ../../hw/top_chip/ip_autogen/pwrmgr/dv/sva/pwrmgr_bind.sv
[pwrmgr_unit_only_bind.sv]: ../../hw/top_chip/ip_autogen/pwrmgr/dv/sva/pwrmgr_unit_only_bind.sv
[COSMIC reports dashboard]: https://dashboard.reports.lowrisc.org/cosmic/mocha/dashboard.html
[OpenTitan power manager checklist]: ../../hw/top_chip/ip_autogen/pwrmgr/doc/checklist.md
