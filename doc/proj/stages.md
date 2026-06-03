# Design and verification stages

In CHERI Mocha we have stages to measure the design and verification progress.
Moving from one stage to another requires a formal checklist and sign-off.
The design stages are inspired by [OpenTitan's development stages](https://opentitan.org/book/doc/project_governance/development_stages.html).
The checklists are inspired by [OpenTitan's checklists](https://opentitan.org/book/doc/project_governance/checklist/index.html).
Slight modification to the stages and checklists were made to meet the requirements for the COSMIC project.

## Current status

This table shows the current design and verification stage for each block in Mocha.

| **DUT name**          | **Design stage** | **Verification stage** |
|-----------------------|------------------|------------------------|
| AXI crossbar          | D0               | V0                     |
| Clock manager         | D0               | V0                     |
| CVA6-CHERI            | D0               | V0                     |
| Debug module          | D0               | V0                     |
| Entropy source        | D0               | V0                     |
| GPIO                  | D0               | V0                     |
| I2C                   | D0               | V0                     |
| KMAC                  | D0               | V0                     |
| Mailbox               | D0               | V0                     |
| PLIC                  | D0               | V0                     |
| Power manager         | D0               | V0                     |
| Reset manager         | D0               | V0                     |
| ROM control           | D0               | V0                     |
| SPI device            | D0               | V0                     |
| SPI host              | D0               | V0                     |
| SRAM                  | D0               | V0                     |
| Tag controller        | D0               | V0                     |
| [TileLink crossbar][] | D0               | V1                     |
| Timer                 | D0               | V0                     |
| [UART][]              | D1               | V1                     |
|                       |                  |                        |
| Top chip              | N/A*             | V0                     |

[TileLink crossbar]: xbar_peri.md
[UART]: uart.md

*The top chip integration has no design stage.
Its verification stages are defined separately in [Top-level chip verification](#top-level-chip-verification).

## Sign-off procedure

To advance a block from one stage to the next you must open a pull request with the checklist in a Markdown file called `doc/proj/BLOCK.md`, where `BLOCK` is replaced by the block's name.
A [checklist template](checklist_template.md) is provided as a starting point.
This pull request must be approved by at least three people, one of whom should ideally be someone who has not been involved in the design and the verification of the block.
It should also update [the table](#current-status) documenting the current status of each block.

## Hardware IP block design stages

These are the stages each block goes through.

| **Stage** | **Name** | **Definition** |
|-----------|----------|----------------|
| D0  | Initial Work | RTL being developed, not functional. |
| D1  | Functional | <ul> <li> Feature set finalized, spec complete </li> <li> CSRs identified; RTL/DV/SW collateral generated </li> <li> SW interface automation completed </li> <li> Clock(s) and reset(s) connected to all sub modules </li> <li> Lint run setup </li> </ul> |
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

## Hardware IP block verification stages

These are the verification stages each block goes through.
Some items are marked as only for *simulation* or only for *formal* depending on which approaches are used in the verification process.

| **Stage** | **Name** | **Definition** |
|-----------|----------|----------------|
| V0  | Initial Work | Testbench being developed, not functional; testplan being written; decide which methodology to use (simulation-based verification, formal-property verification (FPV), or both). |
| V1  | Under Test | <ul> <li> Documentation: <ul> <li> Verification document available </li> <li> Testplan completed and reviewed </li> </ul> </li> <li> Testbench: <ul> <li> *Simulation:* Device under test (DUT) instantiated with major interfaces hooked up </li> <li> *Formal:* Testbench with DUT bound to assertion module(s) </li> <li> All available interface assertion monitors hooked up </li> <li> X / unknown checks on DUT outputs added </li> <li> Skeleton environment created with universal verification components </li> <li> Bus connections made from interface monitors to the scoreboard </li> </ul> </li> <li> *Simulation* tests (written and passing): <ul> <li> Sanity test accessing basic functionality </li> <li> Register / memory test suite </li> </ul> </li> <li> *Formal* assertions (written and proven): <ul> <li> All functional properties identified and described in testplan </li> <li> Assertions for main functional path implemented and passing (smoke check) </li> <li> Each input and each output is part of at least one assertion </li> </ul> </li> <li> Regressions: Nightly regression set up </li> </ul> |
| V2  | Testing Complete | <ul> <li> Documentation: <ul> <li> Verification document completely written </li> </ul> </li> <li> Design issues: <ul> <li> All high priority bugs addressed </li> <li> Low priority bugs root-caused </li> </ul> </li> <li> *Simulation* testbench: <ul> <li> All interfaces hooked up and exercised </li> <li> All assertions written and enabled </li> <li> Universal verification methodology (UVM) environment: fully developed with end-to-end checks in scoreboard </li> </ul> <li> *Formal* testbench: <ul> <li> All interfaces have assertions checking the protocol </li> <li> All functional assertions written and enabled </li> <li> Assumptions for FPV specified and reviewed </li> </ul> </li> </li>  <li> Tests (written and passing): all tests planned for in the testplan </li> <li> *Simulation* functional coverage: all covergroups planned for in the testplan </li> <li> Regression: <ul> <li> *Simulation:* all tests passing in nightly regression with multiple seeds (> 90%) </li> <li> *Formal:* 90% of properties proven in nightly regression </li> </ul> <li> Coverage: <ul> <li> 90% code coverage combining simulation and formal </li> <li> *Simulation:* 90% functional coverage </li> <li> *Formal:* 75% logic cone of influence (COI) coverage for blocks using formal-only verification </li> </ul> </li> </ul> |
| V2S | Security Countermeasures Verified | In OpenTitan this is used to show that all tests are written and passing for the security countermeasures. In Mocha we don't currently plan to use this stage. |
| V3  | Verification Complete | <ul> <li> Design issues: all bugs addressed </li> <li> *Simulation* tests (written and passing): all tests including newly added post-V2 tests (if any) </li> <li> Regression: <ul> <li> *Simulation:* all tests with all seeds passing </li> <li> 100% of properties proven (with reviewed assumptions) </li> </ul> <li> Coverage: <ul> <li> 100% code coverage combining simulation and formal </li> <li> *Simulation:* 100% functional coverage with waivers </li> <li> *Formal:* 100% COI coverage for formal-only testbenches </li> </ul> </li> </ul> |

### V1 verification sign-off checklist

Checklist for signing off a block at V1.

| **Item name** | **Applies to** | **Description** |
|---------------|----------------|-----------------|
| DV_DOC_DRAFT_COMPLETED | *Both* | Verification document drafted with overall goal and strategy. |
| TESTPLAN_COMPLETED | *Both* | Initial test plan drafted including test points and a functional coverage plan. |
| TB_TOP_CREATED | *Both* | Top-level testbench created with DUT instantiated. Memory bus, clocks, resets and interrupts connected where applicable. |
| PRELIMINARY_ASSERTION_CHECKS_ADDED | *Both* | Available interface assertions connected up, like tlul_assert. |
| PRE_VERIFIED_SUB_MODULES_V1 | *Both* | Pre-verified sub-modules must also have reached V1. |
| DESIGN_SPEC_REVIEWED | *Both* | Review the design specification. |
| TESTPLAN_REVIEWED | *Both* | Review the software tests proposed by the testplan. |
| STD_TEST_CATEGORIES_PLANNED | *Both* | The following categories of post-V1 tests have been focused on during testplan review (where applicable): error scenarios, power, performance, debug and stress.
| SIM_TB_ENV_CREATED | *Simulation* | A UVM environment has been created with major interface agents connected. Any monitors at this point have been connected to the scoreboard. |
| SIM_SMOKE_TEST_PASSING | *Simulation* | Smoketest passing in simulation with a particular seed. |
| SIM_SMOKE_REGRESSION_SETUP | *Simulation* | Regression smoke tests selected and defined. |
| SIM_NIGHTLY_REGRESSION_SETUP | *Simulation* | Regression nightly tests selected and defined. |
| SIM_COVERAGE_MODEL_ADDED | *Simulation* | Initial functional coverage model added to the testbench environment. |
| FPV_MAIN_ASSERTIONS_PROVEN | *Formal* | Each input and each output of the module is part of at least one assertion. Assertions for the main functional path are implemented and proven. |
| FPV_REGRESSION_SETUP | *Formal* | An FPV regression has been set up and added to `top_chip_fpv_ip_cfgs.hjson` |

*V2 and V3 checklists to be added.*

## Top-level chip verification

These stages apply to the `top_chip` integration testbench.
The two key documents governing chip-level verification are:

- **Verification plan** (primary): [`hw/top_chip/dv/data/top_mocha_vplan.hjson`](../../hw/top_chip/dv/data/top_mocha_vplan.hjson) - defines the coverage metrics and their mapping to tests.
- **Testplan**: [`hw/top_chip/data/chip_testplan.hjson`](../../hw/top_chip/data/chip_testplan.hjson) - captures individual testpoints and their associated tests.

Both documents must be kept consistent as milestones progress.

Two standing constraints apply throughout all chip-level milestones:
- **IP floor:** all integrated IP blocks must have reached the corresponding IP verification stage (V1 for chip V1, and so on). Blocks below the floor require a written waiver signed off by the DV lead.
- **Dual firmware mode:** both vanilla (non-CHERI) and CHERI firmware images must pass all applicable tests. A milestone is not met if only one mode passes.

### What top-level tests cover

Top-level tests target integration paths that cannot be observed in any individual IP testbench:

- **Pin connectivity:** IP outputs reach the correct chip pins and external stimulus on input pins is correctly delivered to the right IP.
- **Interrupt routing:** each IP's interrupt signal propagates through the PLIC and arrives as a trap at the CPU. This path crosses multiple IPs and is untestable below the chip level.
- **Cross-IP data paths:** data flowing between two or more IPs - for example the entropy source feeding KMAC masking logic, the ROM controller using the KMAC application interface at boot, or the alert handler forwarding escalation to the reset manager.
- **Clock and reset distribution:** the reset tree and clock gating logic correctly propagate resets and enable/disable clocks across the chip.
- **Boot sequence:** the ROM controller runs its startup routine, passes the integrity check, and transfers execution to the SRAM image before the CPU runs any firmware.
- **CPU integration:** the CPU core is correctly wired into the memory subsystem, interrupt infrastructure, and debug module. End-to-end tests exercise the full path from a firmware action (instruction fetch, memory access, trap) through the chip fabric and back, confirming the CPU's bus transactions, interrupt acknowledgements, and exception handling are correctly handled by the surrounding logic. Examples include verifying that a memory access produces the expected transaction on the fabric, or that a store correctly updates state in a downstream controller (e.g. setting a tag bit) and a subsequent access reflects that change.

### What top-level tests do not cover

Top-level tests intentionally do not re-verify IP-internal behaviour:

- **CSR correctness:** register reset values, read/write semantics, bit-bash - verified at block level.
- **Protocol compliance:** SPI timing, I2C ACK/NACK handling, UART framing - verified at block level.
- **Error injection and recovery within an IP** - verified at block level.
- **Functional coverage of individual IP RTL** - tracked and closed at block level.

A test that could pass or fail based solely on IP-internal behaviour, with no observable effect at the chip level, does not belong in the chip-level testplan.

### Chip-level stage definitions

| **Stage** | **Name** | **Definition** |
|-----------|----------|----------------|
| V0 | Initial Work | <ul> <li> Chip-level testbench being set up </li> <li> Chip-level verification plan being written </li> <li> Chip-level testplan being written </li> </ul> |
| V1 | Smoke Passing | <ul> <li> All V1 testpoints in the testplan passing (mostly smoke-tests) </li> <li> Testbench infrastructure validated </li> <li> CI smoke regression running </li> </ul> |
| V2 | Integration Complete | <ul> <li> All V1 and V2 testpoints in the testplan passing </li> <li> All chip interfaces connected to an active agent and exercised end-to-end </li> <li> End-to-end interrupt routing confirmed for all interrupt-capable IPs </li> <li> Cross-IP integration paths and reset sequences exercised </li> <li> Chip-level coverage targets met </li> </ul> |
| V3 | Verification Complete | <ul> <li> 100% regression with soak </li> <li> 100% planned coverage </li> <li> All open issues closed or explicitly waived </li> <li> X-propagation clean </li> </ul> |

### Smoke test expectations

A chip-level smoke test verifies one IP at a time and must demonstrate three things:

1. **Register reachability:** SW writes and reads at least one CSR, confirming correct address-map wiring through the crossbar.
2. **One integration-unique functional path:** one transaction that exercises a path only present at the chip level. The chip's external ports relevant to the IP under test must be connected to a UVM agent or a component that actively drives or passively observes them; a port left undriven or tied off does not count as exercised. This distinguishes a chip-level smoke from an IP-level smoke.
3. **At least one interrupt delivery** (where the IP can generate an interrupt): one full machine-mode claim/complete cycle through the PLIC, confirming IP to PLIC to CPU wiring.

Smoke tests must be short and deterministic. A smoke test that fails only because of an IP-internal bug (not a wiring or routing bug) indicates the IP has not yet reached its own V1 milestone and should not be blocking chip V1.

### Top-level V1 sign-off checklist

| **Item name** | **Description** |
|---------------|-----------------|
| TOP_DV_DOC_DRAFTED | DV document drafted covering testbench architecture, agent topology, firmware-driven stimulus model, and chip-level coverage intent. |
| TOP_VPLAN_COMPLETED | Verification plan (`top_mocha_vplan.hjson`) substantively complete (>90% of intended scope) with the metric-to-test mapping for each coverage item and milestone specified. Reviewed and approved by designers, a peer DV engineer, firmware author, and chip architect. Further evolution is expected as the design matures; the review ensures no major coverage gaps or methodological misalignments remain before DV execution begins. |
| TOP_TESTPLAN_COMPLETED | Chip-level testplan (`chip_testplan.hjson`) substantively complete (>90% of intended scope) with at least one testpoint per integrated IP. Reviewed and approved by designers, a peer DV engineer, firmware author, and chip architect. Further evolution is expected as the design matures; the review ensures no major testpoint gaps remain before DV execution begins. |
| TOP_TB_COMPLETED | Top-level testbench instantiates the DUT with all chip interfaces connected to a UVM agent, an interface or a module that can actively drive or passively observe them. Tie-offs are only permitted for interfaces that are architecturally unused; each must be documented with justification. Exceptions require a written waiver signed off by the DV lead. |
| TOP_BOOT_INFRA_PASSING | The SW-to-DV pass/fail signalling mechanism is confirmed working before any other firmware-driven test result is trusted. |
| TOP_ALL_TESTS_PASSING_V1 | All V1 testpoints in the testplan passing. |
| TOP_VPLAN_COVERAGE_V1 | All V1 items defined in the verification plan achieved. |
| TOP_SMOKE_REGRESSION_IN_CI | V1 smoke suite runs automatically on PRs touching top-level RTL or testbench and failures block merge. |
| TOP_WEEKLY_REGRESSION | Full test suite runs on a regular schedule (weekly at minimum; nightly if the CI infrastructure already supports it). This is not a randomness exercise but a health check to detect regressions in non-smoke tests as RTL development progresses between PRs. |

### Top-level V2 sign-off checklist

**Note:**
*This checklist is a proposal, not a strict requirement.*
*Requirements may be refined based on experience gained during V1 and continued design evolution.*

| **Item name** | **Description** |
|---------------|-----------------|
| TOP_DV_DOC_COMPLETED | DV document fully written including testbench architecture, agent topology, and checking strategy. |
| TOP_ALL_INTERFACES_EXERCISED | Every chip-level interface is connected to a UVM agent, or an interface or a module that actively drives or observes it, and exercised by at least one passing test. Tie-offs are only permitted for interfaces that are architecturally unused on this chip variant; each must be documented with justification. |
| TOP_INDEPENDENT_CHECKING | Where feasible at the chip level, test outcomes are independently confirmed by UVM scoreboards, protocol checkers, or assertions. SW-side pass/fail is accepted as the primary checking mechanism where independent observation is not practical. |
| TOP_INTERRUPT_ROUTING | Every interrupt-capable IP has had at least one full end-to-end delivery confirmed: IP source to PLIC to CPU trap, then PLIC claim, interrupt clear, and PLIC complete. Both machine-mode and supervisor-mode paths exercised where applicable. |
| TOP_CROSS_IP_PATHS | Cross-IP integration paths exercised (eg: entropy source to KMAC masking), alert sources through alert handler to escalation and reset manager. |
| TOP_RESET_PATHS | Software reset, NDM reset via the debug module, and alert-escalation reset each exercised: correct reset cause register state confirmed after each. |
| TOP_ALL_TESTS_PASSING_V2 | All V1 and V2 testpoints in the testplan passing; no regression on V1 tests. |
| TOP_VPLAN_COVERAGE_V2 | All V1 and V2 items defined in the verification plan achieved. |
| TOP_GLUE_CODE_COVERAGE_90 | ≥90% line, branch, toggle and FSM code coverage on the top-level glue logic. IP blocks verified at block level are black-boxed; only the integration logic is in scope. |
| TOP_NO_HIGH_PRIORITY_ISSUES | All P0 and P1 bugs closed. |

### Top-level V3 sign-off checklist

**Note:**
*This checklist is a proposal, not a strict requirement.*
*Requirements may be refined based on experience gained during V1 and V2.*

| **Item name** | **Description** |
|---------------|-----------------|
| TOP_ALL_TESTS_PASSING_V3 | All testpoints passing; no regression on prior milestone tests. |
| TOP_VPLAN_COVERAGE_V3 | All items defined in the verification plan achieved. |
| TOP_GLUE_CODE_COVERAGE_100 | 100% line, branch, toggle and FSM code coverage on the top-level glue logic. IP blocks verified at block level are black-boxed; only the integration logic is in scope. Exclusions reviewed and justified. |
| TOP_XPROP_CLEAN | X-propagation enabled in simulation with no X sources in driven logic. |
| TOP_NO_TOOL_WARNINGS | No compile-time or run-time simulator warnings in passing regressions. |
| TOP_TB_LINT_COMPLETE | Testbench lint flow clean; all waiver files reviewed. |
| TOP_NO_TODOS | No TODO comments remaining in testbench code or testplan. |
| TOP_NO_ISSUES_PENDING | All bugs closed; no open issues against top-level DV or RTL. |
