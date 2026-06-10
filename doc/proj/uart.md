# UART

The UART in Mocha is imported from OpenTitan.
The documentation for the hardware IP block is located [in the vendored HW directory tree][block doc].

The rest of this document contains the design and verification checklists for the UART hardware IP block for the CHERI Mocha top.
For more details on the stages and the current state for each block, please refer to the [stages documentation][stages].
To facilitate the sign-off process, we can take inspiration from the [design and verification sign-offs][UART sign-off] done for UART in OpenTitan.

## Design sign-offs

### D1

The UART used for D1 sign-off is the one imported from OpenTitan at revision [d96fc2a][OpenTitan hash].
The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | [UART specification][block doc].
| Documentation | CSR_DEFINED                | Done   | [UART registers][registers].
| RTL           | CLKRST_CONNECTED           | Done   | Modules containing submodules checked: uart.sv, uart_core.sv and uart_reg_top.sv. Modules without clocks and resets are confirmed to be purely combinational: tlul_rsp_intg_gen, prim_subreg_ext and prim_onehot_enc.
| RTL           | IP_TOP                     | Done   | This modules is defined in uart.sv
| RTL           | IP_INSTANTIABLE            | Done   | It is instantiated in top chip system.
| RTL           | PHYSICAL_MACROS_DEFINED_80 | Done   | UART receive and transmit FIFO depths defined in uart_reg_pkg.
| RTL           | FUNC_IMPLEMENTED           | Done   | All functionality already implemented.
| RTL           | ASSERT_KNOWN_ADDED         | Done   | Output assertions are [here][output asserts].
| Code Quality  | LINT_SETUP                 | Done   | This is part of the top Verilator setup. [Two lint warnings are waived][lint waivers] as they are stylistic.

### D2

*Checklist to be defined — see [stages.md][design stages].*

### D3

*Checklist to be defined — see [stages.md][design stages].*

## Verification sign-offs

### V1

All checklist items refer to the [V1 verification sign-off checklist][V1 checklist].
This sign-off is based on commit [`a413a52`][V1 commit].

| Type          | Item                               | Status | Note/Collaterals |
|---------------|------------------------------------|--------|------------------|
| Documentation | DV_DOC_DRAFT_COMPLETED             | Done   | [UART DV document][] describes the goals, testbench architecture, stimulus, coverage and checking strategy |
| Documentation | TESTPLAN_COMPLETED                 | Done   | [UART testplan][] defines the V1 smoke test and post-V1 functional, error, performance and stress testpoints |
| Testbench     | TB_TOP_CREATED                     | Done   | `hw/vendor/lowrisc_ip/ip/uart/dv/tb/tb.sv` instantiates the DUT and connects clock/reset, TileLink, UART, interrupt and alert interfaces |
| Testbench     | PRELIMINARY_ASSERTION_CHECKS_ADDED | Done   | `uart_bind.sv` binds the TLUL protocol and CSR assertions; the UART RTL checks that outputs are known after reset |
| Integration   | PRE_VERIFIED_SUB_MODULES_V1        | Waived | UART and its primitive submodules are vendored from OpenTitan, where UART reached V3 ([OpenTitan UART sign-off][]); Mocha applies no functional RTL patches |
| Review        | DESIGN_SPEC_REVIEWED               | Waived | The specification was reviewed through the OpenTitan sign-off process and the block is imported without functional changes |
| Review        | TESTPLAN_REVIEWED                  | Done   | The vendored [OpenTitan UART checklist][] records the testplan review as complete |
| Review        | STD_TEST_CATEGORIES_PLANNED        | Done   | Error scenarios, performance and stress tests are covered in the [UART testplan][]; security bus-integrity testing is currently out of scope for Mocha; power and debug are N/A |
| Simulation    | SIM_TB_ENV_CREATED                 | Done   | CIP-based UVM environment with TL and UART agents; both agents feed the end-to-end `uart_scoreboard` |
| Tests         | SIM_SMOKE_TEST_PASSING             | Done   | `uart_smoke`: 1/1 passed with Xcelium on June 10, 2026 at commit `a413a52` |
| Regression    | SIM_SMOKE_REGRESSION_SETUP         | Done   | `smoke` regression in `uart_sim_cfg.hjson` selects `uart_smoke`; the aggregate Mocha config imports the UART simulation config |
| Regression    | SIM_NIGHTLY_REGRESSION_SETUP       | Done   | UART is included in `mocha_sim_cfgs.hjson`; results are published on the [COSMIC reports dashboard][] |
| Coverage      | SIM_COVERAGE_MODEL_ADDED           | Done   | UART interface coverage is in `uart_agent_cov.sv`; block-level coverage is in `uart_env_cov.sv` |
| Tests         | FPV_MAIN_ASSERTIONS_PROVEN         | N/A    | This V1 sign-off uses simulation; TLUL and CSR assertions are enabled in the simulation testbench |
| Regression    | FPV_REGRESSION_SETUP               | N/A    | No UART FPV regression is configured in Mocha |

### V2

*Checklist to be defined — see [stages.md][verification stages].*

### V3

*Checklist to be defined — see [stages.md][verification stages].*

[block doc]: ../../hw/vendor/lowrisc_ip/ip/uart/README.md
[stages]: stages.md
[UART sign-off]: https://github.com/lowRISC/opentitan/pull/615
[OpenTitan hash]: https://github.com/lowRISC/opentitan/tree/d96fc2abd7b3c547f8a31ac4cb5a0bac645a7d1f
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[registers]: ../../hw/vendor/lowrisc_ip/ip/uart/doc/registers.md
[output asserts]: ../../hw/vendor/lowrisc_ip/ip/uart/rtl/uart.sv#L122-L127
[lint waivers]: https://github.com/lowRISC/mocha/blob/0d4d6369a57864dab9522ef9000ca8577d803050/hw/top_chip/lint/top_chip_system.vlt#L98-L100
[design stages]: stages.md#design-stages
[V1 checklist]: stages.md#v1-verification-sign-off-checklist
[verification stages]: stages.md#verification-stages
[V1 commit]: https://github.com/lowRISC/mocha/commit/a413a5274bfbdc119dabf16c5ba27d3580b68903
[UART DV document]: ../../hw/vendor/lowrisc_ip/ip/uart/dv/README.md
[UART testplan]: ../../hw/vendor/lowrisc_ip/ip/uart/data/uart_testplan.hjson
[OpenTitan UART checklist]: ../../hw/vendor/lowrisc_ip/ip/uart/doc/checklist.md
[OpenTitan UART sign-off]: https://github.com/lowRISC/opentitan/pull/615
[COSMIC reports dashboard]: https://dashboard.reports.lowrisc.org/cosmic/mocha/dashboard.html
