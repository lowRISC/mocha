# Design and verification stages

In CHERI Mocha we have stages to measure the design and verification progress.
Moving from one stage to another requires a formal checklist and sign-off.
The design stages are inspired by [OpenTitan's development stages](https://opentitan.org/book/doc/project_governance/development_stages.html).
The checklists are inspired by [OpenTitan's checklists](https://opentitan.org/book/doc/project_governance/checklist/index.html).
Slight modification to the stages and checklists were made to meet the requirements for the COSMIC project.

## Current status

This table shows the current design and verification stage for each block in Mocha.

| **Block name**    | **Design stage** | **Verification stage** |
|-------------------|------------------|------------------------|
| CVA6-CHERI        | D0               | V0                     |
| AXI crossbar      | D0               | V0                     |
| TileLink crossbar | D0               | V0                     |
| SRAM              | D0               | V0                     |
| Debug module      | D0               | V0                     |
| Mailbox           | D0               | V0                     |
| GPIO              | D0               | V0                     |
| Clock manager     | D0               | V0                     |
| Reset manager     | D0               | V0                     |
| Power manager     | D0               | V0                     |
| ROM control       | D0               | V0                     |
| Entropy source    | D0               | V0                     |
| KMAC              | D0               | V0                     |
| UART              | D0               | V0                     |
| I2C               | D0               | V0                     |
| SPI device        | D0               | V0                     |
| Timer             | D0               | V0                     |
| SPI host          | D0               | V0                     |
| PLIC              | D0               | V0                     |
| Tag controller    | D0               | V0                     |

## Sign-off procedure

To advance a block from one stage to the next you must open a pull request with the checklist in a markdown file called `doc/verif/BLOCK.md`, where `BLOCK` is replaced by the block's name.
This pull request must be approved by at least three people, one of whom should ideally be someone who has not been involved in the design and the verification of the block.
It should also update the table documenting the current status of each block.

## Design stages

These are the stages each block goes through.

| **Stage** | **Name** | **Definition** |
|-----------|----------|----------------|
| D0  | Initial Work | RTL being developed, not functional. |
| D1  | Functional | <ul> <li> Feature set finalized, spec complete </li> <li> CSRs identified; RTL/DV/SW collateral generated </li> <li> SW interface automation completed </li> <li> Clock(s) and reset(s) connected to all sub modules </li> <li> Lint run setup </li> <li> Ports frozen </li> </ul> |
| D2  | Feature Complete | <ul> <li> All features implemented </li> <li> Feature frozen </li> </ul> |
| D2S | Security Countermeasures Complete | In OpenTitan this stage is used to verify that all security countermeasures implemented. In Mocha we don't currently plan to use this stage. |
| D3  | Design Complete | <ul> <li> Lint/CDC clean, waivers reviewed </li> <li> Design optimisation for power and/or performance complete </li> </ul> |

### D1 design sign-off checklist

Checklists for signing off a block at D1.

| **Item name** | **Description** |
|---------------|-----------------|
| SPEC_COMPLETED | Specification is 90% complete. |
| CSR_DEFINED | Registers defined for the primary programming model. |
| CLKRST_CONNECTED | Clock and reset connected to all submodules. |
| IP_TOP | There is an IP top that can be included in the top design. |
| IP_INSTANTIABLE | The IP compiles and elaborates without errors. |
| PHYSICAL_MACROS_DEFINED_80 | Physical macros for memories and analogue components are defined and roughly 80% accurate. |
| FUNC_IMPLEMENTED | The main functional path is implemented to allow basic testing. |
| ASSERT_KNOWN_ADDED | Assert that all outputs of the blocks are “known.” |
| LINT_SETUP | Lint flow is set up, but it is acceptable to have warnings at this point. |

*D2 and D3 checklists to be added.*

## Verification stages

These are the verification stages each block goes through in case a **simulation-based approach** is taken.

| **Stage** | **Name** | **Definition** |
|-----------|----------|----------------|
| V0  | Initial Work | Testbench being developed, not functional; testplan being written; decide which methodology to use (simulation-based verification, formal-property verification (FPV), or both). |
| V1  | Under Test | <ul> <li> Documentation: <ul> <li> Verification document available, </li> <li> Testplan completed and reviewed </li> </ul> </li> <li> Testbench: <ul> <li> Device under test (DUT) instantiated with major interfaces hooked up </li> <li> All available interface assertion monitors hooked up </li> <li> X / unknown checks on DUT outputs added </li> <li> Skeleton environment created with universal verification components </li> <li> Bus connections made from interface monitors to the scoreboard </li> </ul> </li> <li> Tests (written and passing): <ul> <li> Sanity test accessing basic functionality </li> <li> Register / memory test suite </li> </ul> </li> <li> Regressions: Sanity and nightly regression set up </li> </ul> |
| V2  | Testing Complete | <ul> <li> Documentation: <ul> <li> Verification document completely written </li> </ul> </li> <li> Design issues: <ul> <li> All high priority bugs addressed </li> <li> Low priority bugs root-caused </li> </ul> </li> <li> Testbench: <ul> <li> All interfaces hooked up and exercised </li> <li> All assertions written and enabled </li> </ul> </li> <li> Universal verification methodology (UVM) environment: fully developed with end-to-end checks in scoreboard </li> <li> Tests (written and passing): all tests planned for in the testplan </li> <li> Functional coverage (written): all covergroups planned for in the testplan </li> <li> Regression: all tests passing in nightly regression with multiple seeds (> 90%) </li> <li> Coverage: 90% code coverage across the board and 90% functional coverage </li> </ul> </li> </ul> |
| V2S | Security Countermeasures Verified | In OpenTitan this is used to show that all tests are written and passing for the security countermeasures. In Mocha we don't currently plan to use this stage. |
| V3  | Verification Complete | <ul> <li> Design issues: all bugs addressed </li> <li> Tests (written and passing): all tests including newly added post-V2 tests (if any) </li> <li> Regression: all tests with all seeds passing </li> <li> Coverage: 100% code and 100% functional coverage with waivers </li> </ul> |

The stages are slightly different if **formal-property verification (FPV)** is chosen:

| **Stage** | **Name** | **Definition** |
|-----------|----------|----------------|
| V0  | Initial Work | Same as above |
| V1  | Under Test | <ul> <li> Documentation: <ul> <li> Verification document available, Testplan completed and reviewed </li> </ul> </li> <li> Testbench: <ul> <li> Formal testbench with DUT bound to assertion module(s) </li> <li> All available interface assertion monitors hooked up </li> <li> X / unknown assertions on DUT outputs added </li> </ul> </li> <li> Assertions (written and proven): <ul> <li> All functional properties identified and described in testplan </li> <li> Assertions for main functional path implemented and passing (smoke check) </li> <li> Each input and each output is part of at least one assertion </li> </ul> </li> <li> Regressions: Sanity and nightly regression set up </li> </ul> |
| V2  | Testing Complete | <ul> <li> Documentation: <ul> <li> Verification document completely written </li> </ul> </li> <li> Design issues: <ul> <li> All high priority bugs addressed </li> <li> Low priority bugs root-caused </li> </ul> </li> <li> Testbench: <ul> <li> All interfaces have assertions checking the protocol </li> <li> All functional assertions written and enabled </li> <li> Assumptions for FPV specified and reviewed </li> </ul> </li> <li> Tests (written and passing): all tests planned for in the testplan </li> <li> Regression: 90% of properties proven in nightly regression </li> <li> Coverage: 90% code coverage and 75% logic cone of influence (COI) coverage </li> </ul> |
| V2S | Security Countermeasures Verified | Same as above |
| V3  | Verification Complete | <ul> <li> Design issues: all bugs addressed </li> <li> Assertions (written and proven): all assertions including newly added post-V2 assertions (if any) </li> <li> Regression: 100% of properties proven (with reviewed assumptions) </li> <li> Coverage: 100% code coverage and 100% COI coverage </li> </ul> |

### V1 verification sign-off checklist

Checklist for signing off a block at V1.

| **Item name** | **Description** |
|---------------|-----------------|
| DV_DOC_DRAFT_COMPLETED | Verification document drafted with overall goal and strategy. |
| TESTPLAN_COMPLETED | Initial test plan drafted including test points and a functional coverage plan. |
| SIM_SMOKE_TEST_PASSING | Smoketest passing in simulation with a particular seed. |
| FPV_MAIN_ASSERTIONS_PROVEN | Each input and each output of the module is part of at least one assertion. Assertions for the main functional path are implemented and proven. |
| SIM_SMOKE_REGRESSION_SETUP | Regression smoke tests selected and defined. |
| FPV_REGRESSION_SETUP | An FPV regression has been set up and added to `top_chip_fpv_ip_cfgs.hjson` |
| SIM_NIGHTLY_REGRESSION_SETUP | Regression nightly tests selected and defined. |
| SIM_COVERAGE_MODEL_ADDED | Initial coverage model bound in. |
| PRE_VERIFIED_SUB_MODULES_V1 | Pre-verified sub-modules must also have reached V1. |
| DESIGN_SPEC_REVIEWED | Review the design specification. |
| TESTPLAN_REVIEWED | Review the software tests proposed by the testplan. |

*V2 and V3 checklists to be added.*
