# Timer

The Timer in Mocha is imported from OpenTitan.
The documentation for the hardware IP block is located [in the vendored HW directory tree][block doc].
It is a 64-bit RISC-V machine timer with a 12-bit prescaler and an 8-bit step register, compliant with the RISC-V privileged specification.
The number of timers per hart and the number of harts are configurable, but the implementation connects one timer for one hart, which is what Mocha uses.
The [vendor patches][patch] only fix DV paths and the default simulator; no RTL is modified.

The rest of this document contains the design checklist for the Timer hardware IP block for the CHERI Mocha top.
For more details on the stages and the current state for each block, please refer to the [stages documentation][stages].

## Design sign-offs

### D1

The Timer used for D1 sign-off is the one imported from OpenTitan at revision [`bf4a2b2`][OpenTitan hash].
The checklist rows were set upstream in [this pull request][OpenTitan sign-off], which declares the block at D3 and V3; it is an ancestor of the vendored revision, so those are the rows Mocha inherits, as recorded in the [vendored checklist][OpenTitan rv_timer checklist].
The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].
This sign-off is based on commit [`b597321`][d1-commit].

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | [Timer specification][block doc].
| Documentation | CSR_DEFINED                | Done   | [Timer registers][registers].
| RTL           | CLKRST_CONNECTED           | Done   | Modules containing submodules checked: `rv_timer.sv` and `rv_timer_reg_top.sv`. Modules without clocks and resets are confirmed to be purely combinational: `prim_onehot_enc`, `prim_subreg_ext`, `tlul_cmd_intg_chk` and `tlul_rsp_intg_gen`. The clocked shared submodules instantiated, `prim_intr_hw`, `prim_alert_sender`, `prim_reg_we_check`, `prim_subreg`, `prim_flop` and `tlul_adapter_reg`, have their clock and reset driven from the instantiating module and are not walked further, being covered by their own OpenTitan sign-offs.
| RTL           | IP_TOP                     | Done   | This module is defined in `rv_timer.sv`.
| RTL           | IP_INSTANTIABLE            | Done   | It is instantiated in top chip system.
| RTL           | PHYSICAL_MACROS_DEFINED_80 | Done   | No memory macros or analogue components.
| RTL           | FUNC_IMPLEMENTED           | Done   | All functionality already implemented.
| RTL           | ASSERT_KNOWN_ADDED         | Done   | Output assertions are [here][output asserts] and cover every output.
| Code Quality  | LINT_SETUP                 | Done   | Verilator lint target with `-Wall` in `rv_timer.core` and in the top. rv_timer's own RTL lints clean; the block target currently exits with warnings from unrelated vendored dependencies pulled in via `lowrisc:prim:all`.

### D2

*Checklist to be defined - see [stages.md][design stages].*

### D3

*Checklist to be defined - see [stages.md][design stages].*

## Verification sign-offs

### V1

All checklist items refer to the [V1 verification sign-off checklist][V1 checklist].
This sign-off is based on commit [`d428cd9`][v1-commit].

| Type          | Item                               | Status | Note/Collaterals |
|---------------|------------------------------------|--------|------------------|
| Documentation | DV_DOC_DRAFT_COMPLETED             | Done   | [Timer DV document][] describes the goals, testbench architecture, stimulus, coverage, and checking strategy |
| Documentation | TESTPLAN_COMPLETED                 | Done   | [Timer testplan][] defines the V1 `random` test and post-V1 functional, boundary value and stress testpoints |
| Testbench     | TB_TOP_CREATED                     | Done   | [tb.sv][] instantiates clock and reset, TileLink, interrupt and alert interfaces along with the Timer DUT; the RACL policies are tied to zero |
| Testbench     | PRELIMINARY_ASSERTION_CHECKS_ADDED | Done   | [rv_timer_bind.sv][] binds the TLUL protocol and CSR assertions; the Timer RTL checks that outputs are known after reset |
| Integration   | PRE_VERIFIED_SUB_MODULES_V1        | Waived | The submodules are shared OpenTitan primitives and TileLink adapters (`prim_intr_hw`, `prim_subreg`, `prim_alert_sender`, `tlul_adapter_reg`, etc.), unmodified in Mocha. They are covered through the IPs that instantiate them, so none carries an independent V1 sign-off; the [OpenTitan rv_timer checklist][] records this item as N/A |
| Review        | DESIGN_SPEC_REVIEWED               | Done   | The specification was reviewed through the OpenTitan sign-off process, where the block reached V3, and the [theory of operation][theory] was reviewed against the Mocha instantiation for this sign-off. It describes the single hart, single timer configuration Mocha uses, and the interrupt drives the CVA6-CHERI timer interrupt directly. Mocha has no alert handler or RACL controller, so `alert_tx_o` and `racl_error_o` are left open and the RACL policies are tied to their defaults at the [instantiation][instantiation] |
| Review        | TESTPLAN_REVIEWED                  | Done   | The [OpenTitan rv_timer checklist][] records the testplan review as complete upstream. The V1 testpoints of the [Timer testplan][], `random` plus the imported CSR testpoints, apply as written |
| Review        | STD_TEST_CATEGORIES_PLANNED        | Done   | Reset, boundary value, on-the-fly reconfiguration and stress tests are covered in the [Timer testplan][]; error scenarios are limited to the TL-UL illegal access and bus integrity testpoints imported from the common testplans; security countermeasures are captured in the sec_cm testplan, but V2S is not used in Mocha; power, performance and debug are N/A |
| Simulation    | SIM_TB_ENV_CREATED                 | Done   | CIP-based UVM environment with TL agent and scoreboard; the scoreboard models each timer and checks the interrupt pins |
| Tests         | SIM_SMOKE_TEST_PASSING             | Done   | All V1 testpoints (`rv_timer_random` and the five CSR tests): 30/30 passed, 5 seeds each, with Xcelium on November 12, 2026 at commit `d428cd9` |
| Regression    | SIM_SMOKE_REGRESSION_SETUP         | Done   | `smoke` regression in `rv_timer_sim_cfg.hjson` selects `rv_timer_random`; the aggregate Mocha config imports the Timer simulation config |
| Regression    | SIM_NIGHTLY_REGRESSION_SETUP       | Done   | The Timer is included in `mocha_sim_cfgs.hjson`; results are published on the [COSMIC reports dashboard][] |
| Coverage      | SIM_COVERAGE_MODEL_ADDED           | Done   | Block-level coverage is in `rv_timer_env_cov.sv` |
| Tests         | FPV_MAIN_ASSERTIONS_PROVEN         | N/A    | This V1 sign-off uses simulation; TLUL and CSR assertions are enabled in the simulation testbench |
| Regression    | FPV_REGRESSION_SETUP               | N/A    | No Timer FPV regression is configured in Mocha |

### V2

*Checklist to be defined - see [stages.md][verification stages].*

### V3

*Checklist to be defined - see [stages.md][verification stages].*

[block doc]: ../../hw/vendor/lowrisc_ip/ip/rv_timer/README.md
[stages]: stages.md
[design stages]: stages.md#hardware-ip-block-design-stages
[verification stages]: stages.md#hardware-ip-block-verification-stages
[OpenTitan hash]: https://github.com/lowRISC/opentitan/tree/bf4a2b24e41742151cfce9c4041e959a3ba76ca3
[OpenTitan sign-off]: https://github.com/lowRISC/opentitan/pull/652
[OpenTitan rv_timer checklist]: ../../hw/vendor/lowrisc_ip/ip/rv_timer/doc/checklist.md
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[d1-commit]: https://github.com/lowRISC/mocha/commit/b5973217f704923917e7761f73df7dfcb8d0c345
[registers]: ../../hw/vendor/lowrisc_ip/ip/rv_timer/doc/registers.md
[output asserts]: https://github.com/lowRISC/mocha/blob/b5973217f704923917e7761f73df7dfcb8d0c345/hw/vendor/lowrisc_ip/ip/rv_timer/rtl/rv_timer.sv#L173-L178
[patch]: ../../hw/vendor/patches/lowrisc_ip/rv_timer
[V1 checklist]: stages.md#v1-verification-sign-off-checklist
[v1-commit]: https://github.com/lowRISC/mocha/commit/d428cd9580070a09722130daf1e37db0dd68b975
[theory]: ../../hw/vendor/lowrisc_ip/ip/rv_timer/doc/theory_of_operation.md
[instantiation]: https://github.com/lowRISC/mocha/blob/d428cd9580070a09722130daf1e37db0dd68b975/hw/top_chip/rtl/top_chip_system.sv#L893-L909
[Timer DV document]: ../../hw/vendor/lowrisc_ip/ip/rv_timer/dv/README.md
[Timer testplan]: ../../hw/vendor/lowrisc_ip/ip/rv_timer/data/rv_timer_testplan.hjson
[tb.sv]: ../../hw/vendor/lowrisc_ip/ip/rv_timer/dv/tb/tb.sv
[rv_timer_bind.sv]: ../../hw/vendor/lowrisc_ip/ip/rv_timer/dv/sva/rv_timer_bind.sv
[COSMIC reports dashboard]: https://dashboard.reports.lowrisc.org/cosmic/mocha/dashboard.html
