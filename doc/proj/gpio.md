# GPIO

The GPIO in Mocha is generated with `ipgen` from the OpenTitan `gpio` IP template.
The documentation for the hardware IP block is its [theory of operation][theory], [register mapping][registers], and block [README][block doc].
The register mapping documentation is currently an empty stub but it will be generated once `cmdgen` is imported, as part of [issue #706][cmdgen].
The [Mocha configuration][ipconfig] declares no input period counters.
At the instantiation `GpioAsyncOn` is set so the inputs are synchronised, and hardware strap sampling is disabled, so `sampled_straps_o` is unused.
The [vendor patch][patch] only fixes DV paths and the default simulator in the templates; no RTL is modified.

The rest of this document contains the design checklist for the GPIO hardware IP block for the CHERI Mocha top.
For more details on the stages and the current state for each block, please refer to the [stages documentation][stages].

## Design sign-offs

### D1

The GPIO used for D1 sign-off is generated from the OpenTitan template at revision [bf4a2b2][OpenTitan hash], where it was [signed off to D1][OpenTitan D1 sign-off].
The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].
This sign-off is based on commit [97816a0][d1-commit].

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | [Theory of operation][theory] and [programmer's guide][pguide].
| Documentation | CSR_DEFINED                | Done   | Registers are defined in [gpio.hjson][csrs] and generated into `gpio_reg_pkg.sv` and `gpio_reg_top.sv`.
| RTL           | CLKRST_CONNECTED           | Done   | Modules containing submodules checked: `gpio.sv` and `gpio_reg_top.sv`. Modules without clocks and resets are confirmed to be purely combinational: `prim_onehot_enc`, `prim_subreg_ext`, `tlul_cmd_intg_chk` and `tlul_rsp_intg_gen`.
| RTL           | IP_TOP                     | Done   | This module is defined in `gpio.sv`.
| RTL           | IP_INSTANTIABLE            | Done   | It is instantiated in top chip system.
| RTL           | PHYSICAL_MACROS_DEFINED_80 | N/A    | No memory macros or analogue components.
| RTL           | FUNC_IMPLEMENTED           | Done   | All functionality already implemented.
| RTL           | ASSERT_KNOWN_ADDED         | Done   | Output assertions are [here][output asserts] and cover every output.
| Code Quality  | LINT_SETUP                 | Done   | Verilator lint target with `-Wall` in `gpio.core` and in the top. The block lints clean with no warnings in its own RTL.

### D2

*Checklist to be defined - see [stages.md][design stages].*

### D3

*Checklist to be defined - see [stages.md][design stages].*

## Verification sign-offs

### V1

All checklist items refer to the [V1 verification sign-off checklist][V1 checklist].
This sign-off is based on commit [`97816a0`][v1-commit].

| Type          | Item                               | Status  | Note/Collaterals |
|---------------|------------------------------------|---------|------------------|
| Documentation | DV_DOC_DRAFT_COMPLETED             | Done    | [GPIO DV document][] describes goals, testbench architecture, stimulus, coverage and checking strategy |
| Documentation | TESTPLAN_COMPLETED                 | Done    | [GPIO testplan][] defines V1, V2 and V3 test points |
| Testbench     | TB_TOP_CREATED                     | Done    | `hw/top_chip/ip_autogen/gpio/dv/tb/tb.sv` instantiates the DUT with clock/reset, TileLink, GPIO pins, interrupt and alert interfaces connected |
| Testbench     | PRELIMINARY_ASSERTION_CHECKS_ADDED | Done    | `gpio_bind.sv` binds `tlul_assert` (TLUL protocol checker) and `gpio_csr_assert_fpv` (CSR assertions) |
| Integration   | PRE_VERIFIED_SUB_MODULES_V1        | Waived  | GPIO and its primitive submodules (`prim_filter_ctr`, `prim_subreg`, etc.) are generated from OpenTitan's `ip_templates`, where GPIO reached V2(S) ([OpenTitan GPIO V2(S) sign-off][]) |
| Review        | DESIGN_SPEC_REVIEWED               | Waived  | The specification was reviewed through the OpenTitan sign-off process; block is imported without functional changes |
| Review        | TESTPLAN_REVIEWED                  | Done    | The OpenTitan testplan records testplan review as complete |
| Review        | STD_TEST_CATEGORIES_PLANNED        | Done    | Error scenarios covered by interrupt tests; stress covered by `gpio_filter_stress` and `gpio_stress_all`; reset stress by `gpio_stress_all_with_rand_reset`; power, performance and debug are N/A |
| Simulation    | SIM_TB_ENV_CREATED                 | Done    | CIP-based UVM environment with TL agent and GPIO `pins_if`; `gpio_scoreboard` provides end-to-end checking of GPIO pin values and CSR predictions |
| Tests         | SIM_SMOKE_TEST_PASSING             | Done    | `gpio_smoke`: 50/50 passed with Xcelium on 2026-09-29 at commit `97816a0` |
| Regression    | SIM_SMOKE_REGRESSION_SETUP         | Done    | `smoke` regression in `gpio_sim_cfg.hjson` selects `gpio_smoke`, `gpio_smoke_no_pullup_pulldown`, `gpio_smoke_en_cdc_prim` and `gpio_smoke_no_pullup_pulldown_en_cdc_prim`; imported into aggregate config `mocha_sim_cfgs.hjson`. The `smoke` regression passed with Xcelium on 2026-09-29 at commit `97816a0` (200/200 tests) |
| Regression    | SIM_NIGHTLY_REGRESSION_SETUP       | Done    | GPIO is included in `mocha_sim_cfgs.hjson`; results published on the [COSMIC reports dashboard][] |
| Coverage      | SIM_COVERAGE_MODEL_ADDED           | Done    | Functional coverage model is mainly defined in `hw/top_chip/ip_autogen/gpio/dv/env/gpio_env_cov.sv` |
| Tests         | FPV_MAIN_ASSERTIONS_PROVEN         | N/A     | GPIO verified by simulation only; no FPV flow |
| Regression    | FPV_REGRESSION_SETUP               | N/A     | No FPV for GPIO |

### V2

*Checklist to be defined - see [stages.md][verification stages].*

### V3

*Checklist to be defined - see [stages.md][verification stages].*

[block doc]: ../../hw/top_chip/ip_autogen/gpio/README.md
[stages]: stages.md
[cmdgen]: https://github.com/lowRISC/mocha/issues/706
[design stages]: stages.md#hardware-ip-block-design-stages
[verification stages]: stages.md#hardware-ip-block-verification-stages
[OpenTitan hash]: https://github.com/lowRISC/opentitan/tree/bf4a2b24e41742151cfce9c4041e959a3ba76ca3
[OpenTitan D1 sign-off]: https://github.com/lowRISC/opentitan/pull/676
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[d1-commit]: https://github.com/lowRISC/mocha/commit/97816a09b4bff4fa48c12e586a0fa71a1698836e
[registers]: ../../hw/top_chip/ip_autogen/gpio/doc/registers.md
[csrs]: ../../hw/top_chip/ip_autogen/gpio/data/gpio.hjson
[theory]: ../../hw/top_chip/ip_autogen/gpio/doc/theory_of_operation.md
[pguide]: ../../hw/top_chip/ip_autogen/gpio/doc/programmers_guide.md
[ipconfig]: ../../hw/top_chip/data/gpio_cfg.hjson
[output asserts]: https://github.com/lowRISC/mocha/blob/97816a09b4bff4fa48c12e586a0fa71a1698836e/hw/top_chip/ip_autogen/gpio/rtl/gpio.sv#L242-L257
[patch]: ../../hw/vendor/patches/lowrisc_ip/gpio/0001_fix_paths_and_tool.patch
[V1 checklist]: stages.md#v1-verification-sign-off-checklist
[v1-commit]: https://github.com/lowRISC/mocha/commit/97816a09b4bff4fa48c12e586a0fa71a1698836e
[OpenTitan GPIO V2(S) sign-off]: https://github.com/lowRISC/opentitan/issues/21035
[GPIO DV document]: ../../hw/top_chip/ip_autogen/gpio/dv/README.md
[GPIO testplan]: ../../hw/top_chip/ip_autogen/gpio/data/gpio_testplan.hjson
[COSMIC reports dashboard]: https://cosmic-project.lowrisc.org/reports
