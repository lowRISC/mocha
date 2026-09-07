# SPI host

This checklist covers the [design and verification sign-off][stages] for the SPI host block.

The SPI host block is imported from OpenTitan at revision [`bf4a2b2`][OpenTitan hash]. The documentation is located [here][block doc].
The SPI host drives remote devices over the Serial Peripheral Interface, and is primarily designed for serial NOR flash.
It supports:
* Standard, Dual and Quad SPI commands, at Single Transfer Rate only
* all SPI clock polarity and phase combinations (CPOL, CPHA), plus full-cycle sampling
* separate TX and RX FIFOs (288 and 256 bytes) with an arbitrary byte count per transaction
* a chip select line per target, controlled automatically, with the count set by the `NumCS` parameter
* pass-through mode for coordination with the [SPI device][] block
* two interrupt lines, `error` and `spi_event`, with fine-grain enable registers

Mocha instantiates the block in [`top_chip_system.sv`][instantiation], connected to the peripheral fabric over TileLink-UL through `xbar_peri`, with `NumCS` set to `SPIHostNumCS`; the pass-through input is tied off at the top level, so pass-through is exercised only in the block-level DV environment.

The block-level DV is vendored in from OpenTitan.
The DV environment reuses the CIP-based UVM infrastructure from OpenTitan.
Mocha applies a single patch [0001_Sim_Path_Fixes.patch][] to adjust the testplan and simulation config paths; no RTL logic is modified.

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
This sign-off is based on commit [`32818cb`][v1-commit].

| Type          | Item                               | Status | Note/Collaterals |
|---------------|------------------------------------|--------|------------------|
| Documentation | DV_DOC_DRAFT_COMPLETED             | Done   | [SPI host DV document][] describes the goals, testbench architecture, stimulus, coverage, and checking strategy |
| Documentation | TESTPLAN_COMPLETED                 | Done   | [SPI host testplan][] defines the V1 smoke test and post-V1 functional, error, performance and stress testpoints |
| Testbench     | TB_TOP_CREATED                     | Done   | [tb.sv][] instantiates clock and reset, TileLink, SPI, pass-through, interrupt and alert interfaces along with the SPI host DUT |
| Testbench     | PRELIMINARY_ASSERTION_CHECKS_ADDED | Done   | [spi_host_bind.sv][] binds the TLUL protocol and CSR assertions; the SPI host RTL checks that outputs are known after reset |
| Integration   | PRE_VERIFIED_SUB_MODULES_V1        | Waived | SPI host and its primitive submodules are vendored from OpenTitan, where SPI host reached V2 ([OpenTitan SPI host checklist][]); <br/> Mocha applies no functional changes |
| Review        | DESIGN_SPEC_REVIEWED               | Waived | The specification was reviewed through the OpenTitan sign-off process and the block was imported without functional <br/> changes |
| Review        | TESTPLAN_REVIEWED                  | Done   | The vendored [OpenTitan SPI host checklist][] records the testplan review as complete |
| Review        | STD_TEST_CATEGORIES_PLANNED        | Done   | Error scenarios, performance, overflow, stall and stress tests are covered in the [SPI host testplan][]; <br/> security bus-integrity testing is currently out of scope for Mocha; power and debug are N/A |
| Simulation    | SIM_TB_ENV_CREATED                 | Done   | CIP-based UVM environment with SPI agent and scoreboard |
| Tests         | SIM_SMOKE_TEST_PASSING             | Done   | `spi_host_smoke`: 1/1 passed with Xcelium on August 21, 2026 at commit `32818cb` |
| Regression    | SIM_SMOKE_REGRESSION_SETUP         | Done   | `smoke` regression in `spi_host_sim_cfg.hjson` selects `spi_host_smoke`; the aggregate Mocha config imports the SPI host <br/> simulation config |
| Regression    | SIM_NIGHTLY_REGRESSION_SETUP       | Done   | SPI host is included in `mocha_sim_cfgs.hjson`; results are published on the [COSMIC reports dashboard][] |
| Coverage      | SIM_COVERAGE_MODEL_ADDED           | Done   | Block-level coverage is in `spi_host_env_cov.sv` |
| Tests         | FPV_MAIN_ASSERTIONS_PROVEN         | N/A    | This V1 sign-off uses simulation; TLUL and CSR assertions are enabled in the simulation testbench |
| Regression    | FPV_REGRESSION_SETUP               | N/A    | No SPI host FPV regression is configured in Mocha |

### V2

*Checklist to be defined — see [stages.md][verification stages].*

### V3

*Checklist to be defined — see [stages.md][verification stages].*

<!-- External references -->
[COSMIC reports dashboard]: https://dashboard.reports.lowrisc.org/cosmic/mocha/dashboard.html
[OpenTitan SPI host checklist]: ../../hw/vendor/lowrisc_ip/ip/spi_host/doc/checklist.md
[OpenTitan hash]: https://github.com/lowRISC/opentitan/tree/bf4a2b24e41742151cfce9c4041e959a3ba76ca3

<!-- Stages and checklists -->
[stages]: stages.md
[design stages]: stages.md#design-stages
[verification stages]: stages.md#verification-stages
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[V1 checklist]: stages.md#v1-verification-sign-off-checklist

<!-- Commit anchors -->
<!-- Replace the d1-commit hash once SPI host D1 sign-off happens. -->
[d1-commit]: https://github.com/lowRISC/mocha/commit/1234def
[v1-commit]: https://github.com/lowRISC/mocha/commit/32818cb34909922f6aca375d61758ae63aa3e7da

<!-- Local file references -->
[block doc]: ../../hw/vendor/lowrisc_ip/ip/spi_host/README.md
[instantiation]: ../../hw/top_chip/rtl/top_chip_system.sv#L982
[SPI device]: ../../hw/vendor/lowrisc_ip/ip/spi_device/README.md
[SPI host DV document]: ../../hw/vendor/lowrisc_ip/ip/spi_host/dv/README.md
[SPI host testplan]: ../../hw/vendor/lowrisc_ip/ip/spi_host/data/spi_host_testplan.hjson
[tb.sv]: ../../hw/vendor/lowrisc_ip/ip/spi_host/dv/tb.sv
[spi_host_bind.sv]: ../../hw/vendor/lowrisc_ip/ip/spi_host/dv/sva/spi_host_bind.sv
[0001_Sim_Path_Fixes.patch]: ../../hw/vendor/patches/lowrisc_ip/spi_host/0001_Sim_Path_Fixes.patch
