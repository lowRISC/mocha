# BLOCK

This checklist covers the [design and verification signoffs][stages] for the BLOCK block.

<!-- Replace BLOCK with the block name throughout this file. -->
<!-- Link to the block's documentation or briefly describe the block: its purpose, origin (e.g. vendored from OpenTitan, new Mocha IP), key interfaces, and any reused DV infrastructure. -->

## Design sign-offs

### D1

<!-- Link the git hash this sign-off was based on. -->
The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].

| Type          | Item                       | Status      | Note/Collaterals |
|---------------|----------------------------|-------------|------------------|
| Documentation | SPEC_COMPLETED             | Not Started |
| Documentation | CSR_DEFINED                | Not Started |
| RTL           | CLKRST_CONNECTED           | Not Started |
| RTL           | IP_TOP                     | Not Started |
| RTL           | IP_INSTANTIABLE            | Not Started |
| RTL           | PHYSICAL_MACROS_DEFINED_80 | Not Started |
| RTL           | FUNC_IMPLEMENTED           | Not Started |
| RTL           | ASSERT_KNOWN_ADDED         | Not Started |
| Code Quality  | LINT_SETUP                 | Not Started |

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

[stages]: stages.md
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[design stages]: stages.md#design-stages
[V1 checklist]: stages.md#v1-verification-sign-off-checklist
[verification stages]: stages.md#verification-stages
