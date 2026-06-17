# I2C

The I2C in Mocha is imported from OpenTitan.
The documentation for the hardware IP block is located [in the vendored HW directory tree][block doc].
The block can be programmed in both controller and target modes.
It supports:
* standard, fast, and fast-plus speed modes
* 7-bit target address
* all the mandatory features listed for controllers in [Table 2: I2C specification Rev 6][]
* multi-controller features such as bus arbitration and controller-controller clock synchronization
* clock stretching in both controller and target modes.
`InputDelayCycles` is parameterized to zero and the RAM ports are configured to the single port package default.
The [vendor patch][patch] only fixes DV paths and the default simulator; no RTL is modified.

The rest of this document contains the design checklist for the I2C hardware IP block for the CHERI Mocha top.
For more details on the stages and the current state for each block, please refer to the [stages documentation][stages].

## Design sign-offs

### D1

The I2C used for D1 sign-off is the one imported from OpenTitan at revision [bf4a2b2][OpenTitan hash].
The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].
This sign-off is based on commit [8ac5ce9][d1-commit].

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | [I2C specification][block doc].
| Documentation | CSR_DEFINED                | Done   | [I2C registers][registers].
| RTL           | CLKRST_CONNECTED           | Done   | Modules containing submodules checked: `i2c.sv`, `i2c_core.sv`, `i2c_fifos.sv`, `i2c_fifo_sync_sram_adapter.sv` and `i2c_reg_top.sv`. Modules without clocks and resets are confirmed to be purely combinational: `prim_onehot_enc`, `prim_subreg_ext`, `tlul_cmd_intg_chk` and `tlul_rsp_intg_gen`.
| RTL           | IP_TOP                     | Done   | This module is defined in `i2c.sv`.
| RTL           | IP_INSTANTIABLE            | Done   | It is instantiated in top chip system.
| RTL           | PHYSICAL_MACROS_DEFINED_80 | Done   | The four FIFOs share one single-port RAM instantiated through `prim_ram_1p_adv` in `i2c_fifos.sv`, fixed at 464 entries of 13 bits with no ECC or parity.
| RTL           | FUNC_IMPLEMENTED           | Done   | All functionality already implemented.
| RTL           | ASSERT_KNOWN_ADDED         | Done   | Output assertions are [here][output asserts] and cover every output. 
| Code Quality  | LINT_SETUP                 | Done   | Verilator lint target with `-Wall` in `i2c.core` and in the top. The block lints clean with no warnings in its own RTL.

### D2

*Checklist to be defined - see [stages.md][design stages].*

### D3

*Checklist to be defined - see [stages.md][design stages].*

## Verification sign-offs

### V1

All checklist items refer to the [V1 verification sign-off checklist][V1 checklist].
This sign-off is based on commit [`8ac5ce9`][v1-commit].

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
| Tests         | SIM_SMOKE_TEST_PASSING             | Done   | `i2c_host_smoke` and `i2c_target_smoke`: 50/50 each passed with Xcelium on September 30, 2026 at commit `8ac5ce9` |
| Regression    | SIM_SMOKE_REGRESSION_SETUP         | Done   | `smoke` regression in `i2c_sim_cfg.hjson` selects `i2c_host_smoke`; the aggregate Mocha config imports the I2C <br/> simulation config |
| Regression    | SIM_NIGHTLY_REGRESSION_SETUP       | Done   | I2C is included in `mocha_sim_cfgs.hjson`; results are published on the [COSMIC reports dashboard][] |
| Coverage      | SIM_COVERAGE_MODEL_ADDED           | Done   | I2C interface coverage is in `i2c_agent_cov.sv`; block-level coverage is in `i2c_env_cov.sv` |
| Tests         | FPV_MAIN_ASSERTIONS_PROVEN         | N/A    | This V1 sign-off uses simulation; TLUL and CSR assertions are enabled in the simulation testbench |
| Regression    | FPV_REGRESSION_SETUP               | N/A    | No I2C FPV regression is configured in Mocha |

### V2

*Checklist to be defined - see [stages.md][verification stages].*

### V3

*Checklist to be defined - see [stages.md][verification stages].*

<!-- External references -->
[Table 2: I2C specification Rev 6]: https://assets.nexperia.com/documents/user-manual/UM10204.pdf
[COSMIC reports dashboard]: https://dashboard.reports.lowrisc.org/cosmic/mocha/dashboard.html
[OpenTitan hash]: https://github.com/lowRISC/opentitan/tree/bf4a2b24e41742151cfce9c4041e959a3ba76ca3
[OpenTitan I2C checklist]: ../../hw/vendor/lowrisc_ip/ip/i2c/doc/checklist.md
[OpenTitan V2S stage sign-off]: https://github.com/lowRISC/opentitan/pull/24011

<!-- Stages and checklists -->
[stages]: stages.md
[design stages]: stages.md#hardware-ip-block-design-stages
[verification stages]: stages.md#hardware-ip-block-verification-stages
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[V1 checklist]: stages.md#v1-verification-sign-off-checklist

<!-- Commit anchors -->
[d1-commit]: https://github.com/lowRISC/mocha/commit/8ac5ce9d1e2af59bc12b834f7870e5a797a824a1
[v1-commit]: https://github.com/lowRISC/mocha/commit/8ac5ce9d1e2af59bc12b834f7870e5a797a824a1

<!-- Local file references -->
[block doc]: ../../hw/vendor/lowrisc_ip/ip/i2c/README.md
[registers]: ../../hw/vendor/lowrisc_ip/ip/i2c/doc/registers.md
[output asserts]: https://github.com/lowRISC/mocha/blob/8ac5ce9d1e2af59bc12b834f7870e5a797a824a1/hw/vendor/lowrisc_ip/ip/i2c/rtl/i2c.sv#L157-L181
[patch]: ../../hw/vendor/patches/lowrisc_ip/i2c/0001-Fix-Paths-and-Tool.patch
[I2C DV document]: ../../hw/vendor/lowrisc_ip/ip/i2c/dv/README.md
[I2C testplan]: ../../hw/vendor/lowrisc_ip/ip/i2c/data/i2c_testplan.hjson
[tb.sv]: ../../hw/vendor/lowrisc_ip/ip/i2c/dv/tb/tb.sv
[i2c_bind.sv]: ../../hw/vendor/lowrisc_ip/ip/i2c/dv/sva/i2c_bind.sv
