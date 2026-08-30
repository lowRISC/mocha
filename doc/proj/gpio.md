# GPIO

This checklist covers the [design and verification sign-offs][stages] for the GPIO block.

GPIO is auto-generated for Mocha from OpenTitan's [`ip_templates/gpio`][OT template].
The block provides 32 configurable general-purpose I/O pins with configurable per-pin interrupt detection (rising edge, falling edge, level-high, level-low), direct and masked output modes, an optional 16-cycle noise filter, and hardware strap sampling.
It connects to the Mocha peripheral fabric via TileLink-UL through `xbar_peri`.
The DV environment reuses the CIP-based UVM infrastructure from OpenTitan.
Mocha applies a single patch ([`0001_fix_paths_and_tool.patch`][gpio patch]) to adjust paths and toolchain integration; no RTL logic is modified.

## Design sign-offs

### D1

*Not yet started — see [stages.md][design stages].*

### D2

*Checklist to be defined — see [stages.md][design stages].*

### D3

*Checklist to be defined — see [stages.md][design stages].*

## Verification sign-offs

### V1

All checklist items refer to the [V1 verification sign-off checklist][V1 checklist].
This sign-off is based on commit [`99206f4`][v1-commit] (nightly 2026-06-16).

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
| Tests         | SIM_SMOKE_TEST_PASSING             | Done    | `gpio_smoke`: 50/50 passed with Xcelium on 2026-06-16 at commit `99206f4` |
| Regression    | SIM_SMOKE_REGRESSION_SETUP         | Done    | `smoke` regression in `gpio_sim_cfg.hjson` selects `gpio_smoke`, `gpio_smoke_no_pullup_pulldown`, `gpio_smoke_en_cdc_prim` and `gpio_smoke_no_pullup_pulldown_en_cdc_prim`; imported into aggregate config `mocha_sim_cfgs.hjson`. The `smoke` regression passed with Xcelium on 2026-06-16 at commit `99206f4` (200/200 tests) |
| Regression    | SIM_NIGHTLY_REGRESSION_SETUP       | Done    | GPIO is included in `mocha_sim_cfgs.hjson`; results published on the [COSMIC reports dashboard][] |
| Coverage      | SIM_COVERAGE_MODEL_ADDED           | Done    | Functional coverage model is mainly defined in `hw/top_chip/ip_autogen/gpio/dv/env/gpio_env_cov.sv` |
| Tests         | FPV_MAIN_ASSERTIONS_PROVEN         | N/A     | GPIO verified by simulation only; no FPV flow |
| Regression    | FPV_REGRESSION_SETUP               | N/A     | No FPV for GPIO |

### V2

*Checklist to be defined — see [stages.md][verification stages].*

### V3

*Checklist to be defined — see [stages.md][verification stages].*

[stages]: stages.md
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[design stages]: stages.md#design-stages
[V1 checklist]: stages.md#v1-verification-sign-off-checklist
[verification stages]: stages.md#verification-stages
[v1-commit]: https://github.com/lowRISC/mocha/commit/99206f4
[OT template]: https://github.com/lowRISC/opentitan/tree/master/hw/ip_templates/gpio
[gpio patch]: ../../hw/vendor/patches/lowrisc_ip/gpio/0001_fix_paths_and_tool.patch
[OpenTitan GPIO V2(S) sign-off]: https://github.com/lowRISC/opentitan/issues/21035
[gpio spec]: ../../hw/top_chip/ip_autogen/gpio/README.md
[gpio registers]: ../../hw/top_chip/ip_autogen/gpio/data/gpio.hjson
[output asserts]: ../../hw/top_chip/ip_autogen/gpio/rtl/gpio.sv#L242-L246
[GPIO DV document]: ../../hw/top_chip/ip_autogen/gpio/dv/README.md
[GPIO testplan]: ../../hw/top_chip/ip_autogen/gpio/data/gpio_testplan.hjson
[COSMIC reports dashboard]: https://cosmic-project.lowrisc.org/reports
