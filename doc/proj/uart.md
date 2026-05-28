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

<!-- Link the git hash this sign-off was based on. -->
All checklist items refer to the [V1 verification sign-off checklist][V1 checklist].

| Type          | Item                               | Status      | Note/Collaterals |
|---------------|------------------------------------|-------------|------------------|
| Documentation | DV_DOC_DRAFT_COMPLETED             | Not Started |
| Documentation | TESTPLAN_COMPLETED                 | Not Started |
| Testbench     | TB_TOP_CREATED                     | Not Started |
| Testbench     | PRELIMINARY_ASSERTION_CHECKS_ADDED | Not Started |
| Integration   | PRE_VERIFIED_SUB_MODULES_V1        | Not Started |
| Review        | DESIGN_SPEC_REVIEWED               | Not Started |
| Review        | TESTPLAN_REVIEWED                  | Not Started |
| Review        | STD_TEST_CATEGORIES_PLANNED        | Not Started |
| Simulation    | SIM_TB_ENV_CREATED                 | Not Started | <!-- Set to N/A if formal-only -->
| Tests         | SIM_SMOKE_TEST_PASSING             | Not Started | <!-- Set to N/A if formal-only -->
| Regression    | SIM_SMOKE_REGRESSION_SETUP         | Not Started | <!-- Set to N/A if formal-only -->
| Regression    | SIM_NIGHTLY_REGRESSION_SETUP       | Not Started | <!-- Set to N/A if formal-only -->
| Coverage      | SIM_COVERAGE_MODEL_ADDED           | Not Started | <!-- Set to N/A if formal-only -->
| Tests         | FPV_MAIN_ASSERTIONS_PROVEN         | Not Started | <!-- Set to N/A if simulation-only -->
| Regression    | FPV_REGRESSION_SETUP               | Not Started | <!-- Set to N/A if simulation-only -->

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
