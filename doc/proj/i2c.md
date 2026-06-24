# I2C

This checklist covers the [design and verification sign-off][stages] for the I2C block.

The I2C block is imported from OpenTitan. The documentation is located [here][block doc].
The I2C block can be programmed in both controller and target modes.
It supports:
* standard, fast, and fast-plus speed modes
* 7-bit target address
* all the mandatory features listed for controllers in [Table 2: I2C specification Rev 6][]
* multi-controller features such as bus arbitration and controller-controller clock synchronization
* clock stretching in both controller and target modes

The block-level DV is vendored in from OpenTitan.
The DV environment reuses the CIP-based UVM infrastructure from OpenTitan.
Mocha applies a single patch [0001-Fix-Paths-and-Tool.patch][] to adjust files and tool paths; no RTL logic is modified.

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
This sign-off is based on commit [`9173e84`][v1-commit] (nightly 2026-06-17).

| Type          | Item                               | Status | Note/Collaterals |
|---------------|------------------------------------|--------|------------------|
| Documentation | DV_DOC_DRAFT_COMPLETED             | Done   | [I2C DV document][] describes the goals, testbench architecture, stimulus, coverage, and checking strategy |
| Documentation | TESTPLAN_COMPLETED                 | Done   | [I2C testplan][] defines the V1 smoke test and post-V1 functional, error, performance and stress testpoints |
| Testbench     | TB_TOP_CREATED                     | Done   | [tb.sv][] instantiates clock and reset, TileLink, I2C, and interrupt interfaces along with the I2C DUT |
| Testbench     | PRELIMINARY_ASSERTION_CHECKS_ADDED | Done   | [i2c_bind.sv][] binds the TLUL protocol and CSR assertions; the I2C RTL checks that outputs are known after reset |
| Integration   | PRE_VERIFIED_SUB_MODULES_V1        | Waived | I2C and its primitive submodules are vendored from OpenTitan, where I2C reached [OpenTitan V2S stage sign-off][]; <br/> Mocha applies no functional changes |
| Review        | DESIGN_SPEC_REVIEWED               | Waived | The specification was reviewed through the OpenTitan sign-off process and the block was imported without functional <br/> changes |
| Review        | TESTPLAN_REVIEWED                  | Done   | The vendored [OpenTitan I2C checklist][] records the testplan review as complete |
| Review        | STD_TEST_CATEGORIES_PLANNED        | Done   | Error scenarios, performance, overflow, timeout, glitch, and stress tests are covered in the [I2C testplan][]; <br/> security bus-integrity testing is currently out of scope for Mocha; power and debug are N/A |
| Simulation    | SIM_TB_ENV_CREATED                 | Done   | CIP-based UVM environment with I2C agent and scoreboard |
| Tests         | SIM_SMOKE_TEST_PASSING             | Done   | `host_smoke` and `target_smoke`: 50/50 passed with Xcelium on June 18, 2026 at commit `9173e84` |
| Regression    | SIM_SMOKE_REGRESSION_SETUP         | Done   | `smoke` regression in `i2c_sim_cfg.hjson` selects `i2c_host_smoke`; the aggregate Mocha config imports the I2C <br/> simulation config |
| Regression    | SIM_NIGHTLY_REGRESSION_SETUP       | Done   | I2C is included in `mocha_sim_cfgs.hjson`; results are published on the a private regression dashboard |
| Coverage      | SIM_COVERAGE_MODEL_ADDED           | Done   | I2C interface coverage is in `i2c_agent_cov.sv`; block-level coverage is in `i2c_env_cov.sv` |
| Tests         | FPV_MAIN_ASSERTIONS_PROVEN         | N/A    | This V1 sign-off uses simulation; TLUL and CSR assertions are enabled in the simulation testbench |
| Regression    | FPV_REGRESSION_SETUP               | N/A    | No I2C FPV regression is configured in Mocha |

### V2

*Checklist to be defined — see [stages.md][verification stages].*

### V3

*Checklist to be defined — see [stages.md][verification stages].*

<!-- External references -->
[Table 2: I2C specification Rev 6]: https://assets.nexperia.com/documents/user-manual/UM10204.pdf
[COSMIC reports dashboard]: https://dashboard.reports.lowrisc.org/cosmic/mocha/dashboard.html
[OpenTitan I2C checklist]: ../../hw/vendor/lowrisc_ip/ip/i2c/doc/checklist.md
[OpenTitan V2S stage sign-off]: https://github.com/lowRISC/opentitan/pull/24011

<!-- Stages and checklists -->
[stages]: stages.md
[design stages]: stages.md#design-stages
[verification stages]: stages.md#verification-stages
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[V1 checklist]: stages.md#v1-verification-sign-off-checklist

<!-- Commit anchors -->
<!-- Replace the d1-commit hash once I2C D1 sign-off happens. -->
[d1-commit]: https://github.com/lowRISC/mocha/commit/1234def
[v1-commit]: https://github.com/lowRISC/mocha/commit/9173e84

<!-- Local file references -->
[block doc]: ../../hw/vendor/lowrisc_ip/ip/i2c/README.md
[I2C DV document]: ../../hw/vendor/lowrisc_ip/ip/i2c/dv/README.md
[I2C testplan]: ../../hw/vendor/lowrisc_ip/ip/i2c/data/i2c_testplan.hjson
[tb.sv]: ../../hw/vendor/lowrisc_ip/ip/i2c/dv/tb/tb.sv
[i2c_bind.sv]: ../../hw/vendor/lowrisc_ip/ip/i2c/dv/sva/i2c_bind.sv
[0001-Fix-Paths-and-Tool.patch]: ../../hw/vendor/patches/lowrisc_ip/i2c/0001-Fix-Paths-and-Tool.patch
