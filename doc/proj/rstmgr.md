# Reset manager

The Reset manager in Mocha is generated with `ipgen` from the OpenTitan `rstmgr` IP template.
The documentation for the hardware IP block is its [theory of operation][theory], [register mapping][registers] and block [README][block doc].
The [register mapping][registers] and [programmer's guide][pguide] are currently empty stubs, and only the README's regression-links block is empty; they will be generated once `cmdgen` is imported, as part of [issue #706][cmdgen].
It generates the chip's reset tree, holds the software-controllable peripheral resets, records the cause of the last reset, and checks that each leaf reset actually takes effect.
The [Mocha configuration][ipconfig] declares `aon`, `io` and `main` clocks and the reset requests the power manager can raise.
The [vendor patches][patch] fix DV paths and the default simulator, correct the templates, rework the cascade assertions for the Mocha reset tree, and [add the missing `sw_rst_req_o` output known assertion][assert patch]; the logic is unchanged.

The rest of this document contains the design checklist for the Reset manager hardware IP block for the CHERI Mocha top.
For more details on the stages and the current state for each block, please refer to the [stages documentation][stages].

## Design sign-offs

### D1

The Reset manager used for D1 sign-off is generated from the OpenTitan template at revision [`bf4a2b2`][OpenTitan hash].
The D1 checklist rows were set upstream in [`51a2342`][OpenTitan D1 transition] and carried into the IP template unchanged; upstream has since declared the block at D3 in [this pull request][OpenTitan D3 sign-off].
Both are ancestors of the vendored revision, so those are the rows Mocha inherits, as recorded in the [vendored checklist][OpenTitan rstmgr checklist].
The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].
This sign-off is based on commit [`d918b3e`][d1-commit].

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | [Theory of operation][theory], which carries the block specification.
| Documentation | CSR_DEFINED                | Done   | Registers are defined in [rstmgr.hjson][csrs] and generated into `rstmgr_reg_pkg.sv` and `rstmgr_reg_top.sv`.
| RTL           | CLKRST_CONNECTED           | Done   | Modules containing submodules checked: `rstmgr.sv`, `rstmgr_ctrl.sv`, `rstmgr_por.sv`, `rstmgr_leaf_rst.sv`, `rstmgr_cnsty_chk.sv` and `rstmgr_reg_top.sv`; `rstmgr_crash_info.sv` takes a clock and reset and instantiates no submodules. `prim_subreg_ext`, `tlul_cmd_intg_chk` and `tlul_rsp_intg_gen` have no clock or reset and are confirmed to be purely combinational; `prim_clock_mux2` and `prim_clock_buf` have no reset and take only the clocks they select between or buffer. The clocked shared submodules: `prim_alert_sender`, `prim_flop`, `prim_flop_2sync`, `prim_mubi4_sender`, `prim_mubi4_sync`, `prim_reg_we_check`, `prim_rst_sync`, `prim_subreg`, `prim_sync_reqack` and `tlul_adapter_reg` have their clock and reset driven from the instantiating module and are not walked further, being covered by their own OpenTitan sign-offs.
| RTL           | IP_TOP                     | Done   | This module is defined in `rstmgr.sv`.
| RTL           | IP_INSTANTIABLE            | Done   | It is instantiated in top chip system.
| RTL           | PHYSICAL_MACROS_DEFINED_80 | Done   | No memory macros or analogue components.
| RTL           | FUNC_IMPLEMENTED           | Done   | All functionality already implemented.
| RTL           | ASSERT_KNOWN_ADDED         | Done   | Output assertions are [here][output asserts] and cover every output; the `sw_rst_req_o` assertion is added by [`0004_Add_Missing_Output_Assertions.patch`][assert patch].
| Code Quality  | LINT_SETUP                 | Done   | Verilator lint target with `-Wall` in `rstmgr.core` and in the top. One synchronous-versus-asynchronous reset warning on the leaf reset output [is waived][lint waivers].

### D2

*Checklist to be defined - see [stages.md][design stages].*

### D3

*Checklist to be defined - see [stages.md][design stages].*

## Verification sign-offs

### V1

All checklist items refer to the [V1 verification sign-off checklist][V1 checklist].
This sign-off is based on commit [`d918b3e`][v1-commit].

| Type          | Item                               | Status | Note/Collaterals |
|---------------|------------------------------------|--------|------------------|
| Documentation | DV_DOC_DRAFT_COMPLETED             | Done   | [Reset manager DV document][] describes the goals, testbench architecture, stimulus, coverage, and checking strategy |
| Documentation | TESTPLAN_COMPLETED                 | Done   | [Reset manager testplan][] defines the V1 smoke test and post-V1 reset, crash dump capture, software reset and stress testpoints |
| Testbench     | TB_TOP_CREATED                     | Done   | [tb.sv][] instantiates the four clocks, TileLink, alert and reset manager interfaces along with the reset manager DUT; the block has no interrupts |
| Testbench     | PRELIMINARY_ASSERTION_CHECKS_ADDED | Done   | [rstmgr_bind.sv][] binds the TLUL protocol, CSR and reset cascading assertions; the reset manager RTL checks that outputs are known after reset |
| Integration   | PRE_VERIFIED_SUB_MODULES_V1        | Waived | Generated from the OpenTitan template, where the block reached V2S ([OpenTitan rstmgr checklist][]); `rstmgr_cnsty_chk` has its own DV environment, not yet in the Mocha config |
| Review        | DESIGN_SPEC_REVIEWED               | Done   | The specification was reviewed through the OpenTitan sign-off process, and the [theory of operation][theory] was reviewed against the Mocha instantiation for this sign-off. It describes the reset trees and their behaviour correctly but is written for the OpenTitan configuration; the differences, including that `ALERT_INFO` and `CPU_INFO` never record real state because the dump inputs are tied off, are listed alongside Mocha's reset tree, power domains and software resets in the [reset domains section][arch resets] of the architecture document |
| Review        | TESTPLAN_REVIEWED                  | Done   | The generated [OpenTitan rstmgr checklist][] records the testplan review as complete upstream. The [Reset manager testplan][] is identical to the one in `ip_templates/rstmgr` and has not been revised for Mocha. Its V1 testpoints are `smoke` plus the six imported from [`csr_testplan.hjson`][csr testplan], all written generically and covering the Mocha reset set as instantiated |
| Review        | STD_TEST_CATEGORIES_PLANNED        | Done   | Reset race, stress, and the debug and low-power reset paths are covered in the [Reset manager testplan][] |
| Simulation    | SIM_TB_ENV_CREATED                 | Done   | CIP-based UVM environment with TL agent and scoreboard |
| Tests         | SIM_SMOKE_TEST_PASSING             | Done   | `rstmgr_smoke`: 1/1 passed with Xcelium on September 30, 2026 at commit `d918b3e` |
| Regression    | SIM_SMOKE_REGRESSION_SETUP         | Done   | `smoke` regression in `rstmgr_sim_cfg.hjson` selects `rstmgr_smoke`; the aggregate Mocha config imports the reset manager simulation config |
| Regression    | SIM_NIGHTLY_REGRESSION_SETUP       | Done   | The Reset manager is included in `mocha_sim_cfgs.hjson`, so it runs as part of the aggregate nightly regression; results are published on the [COSMIC dashboard][] |
| Coverage      | SIM_COVERAGE_MODEL_ADDED           | Done   | Block-level coverage is in `rstmgr_env_cov.sv` |
| Tests         | FPV_MAIN_ASSERTIONS_PROVEN         | N/A    | This V1 sign-off uses simulation; TLUL and CSR assertions are enabled in the simulation testbench |
| Regression    | FPV_REGRESSION_SETUP               | N/A    | No Reset manager FPV regression is configured in Mocha |

### V2

*Checklist to be defined - see [stages.md][verification stages].*

### V3

*Checklist to be defined - see [stages.md][verification stages].*

[block doc]: ../../hw/top_chip/ip_autogen/rstmgr/README.md
[stages]: stages.md
[design stages]: stages.md#hardware-ip-block-design-stages
[verification stages]: stages.md#hardware-ip-block-verification-stages
[OpenTitan hash]: https://github.com/lowRISC/opentitan/tree/bf4a2b24e41742151cfce9c4041e959a3ba76ca3
[OpenTitan D1 transition]: https://github.com/lowRISC/opentitan/commit/51a23424ec66cece8c179f67388efa7cdad34381
[OpenTitan D3 sign-off]: https://github.com/lowRISC/opentitan/pull/24164
[OpenTitan rstmgr checklist]: ../../hw/top_chip/ip_autogen/rstmgr/doc/checklist.md
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[V1 checklist]: stages.md#v1-verification-sign-off-checklist
[d1-commit]: https://github.com/lowRISC/mocha/commit/d918b3ef1b80febeccbae3c9d7d8b30edf8a1186
[v1-commit]: https://github.com/lowRISC/mocha/commit/d918b3ef1b80febeccbae3c9d7d8b30edf8a1186
[arch resets]: ../ref/arch.md#reset-domains
[theory]: ../../hw/top_chip/ip_autogen/rstmgr/doc/theory_of_operation.md
[pguide]: ../../hw/top_chip/ip_autogen/rstmgr/doc/programmers_guide.md
[registers]: ../../hw/top_chip/ip_autogen/rstmgr/doc/registers.md
[csrs]: ../../hw/top_chip/ip_autogen/rstmgr/data/rstmgr.hjson
[ipconfig]: ../../hw/top_chip/data/rstmgr_cfg.hjson
[cmdgen]: https://github.com/lowRISC/mocha/issues/706
[output asserts]: https://github.com/lowRISC/mocha/blob/d918b3ef1b80febeccbae3c9d7d8b30edf8a1186/hw/top_chip/ip_autogen/rstmgr/rtl/rstmgr.sv#L698-L704
[lint waivers]: https://github.com/lowRISC/mocha/blob/d918b3ef1b80febeccbae3c9d7d8b30edf8a1186/hw/top_chip/lint/top_chip_system.vlt#L55
[patch]: ../../hw/vendor/patches/lowrisc_ip/rstmgr
[assert patch]: ../../hw/vendor/patches/lowrisc_ip/rstmgr/0004_Add_Missing_Output_Assertions.patch
[Reset manager DV document]: ../../hw/top_chip/ip_autogen/rstmgr/dv/README.md
[COSMIC dashboard]: https://cosmic-project.lowrisc.org/dashboard/index.html
[csr testplan]: ../../hw/vendor/lowrisc_ip/dv/tools/dvsim/testplans/csr_testplan.hjson
[Reset manager testplan]: ../../hw/top_chip/ip_autogen/rstmgr/data/rstmgr_testplan.hjson
[tb.sv]: ../../hw/top_chip/ip_autogen/rstmgr/dv/tb.sv
[rstmgr_bind.sv]: ../../hw/top_chip/ip_autogen/rstmgr/dv/sva/rstmgr_bind.sv
