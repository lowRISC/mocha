# SPI device

This checklist covers the [design and verification sign-off][stages] for the SPI device block.

The SPI device block is imported from OpenTitan at revision [`bf4a2b2`][OpenTitan hash]. The documentation is located [here][block doc].
The SPI device emulates a serial NOR flash towards an external host, and can pass transactions through to a downstream flash device.
It supports:
* serial flash emulation, with Read Status, Read JEDEC ID, Read SFDP, EN4B/EX4B and read commands processed in hardware
* Normal, Fast, Fast Dual Output and Fast Quad Output reads; Dual IO, Quad IO and QPI commands are not supported
* command upload through 16-entry command and address FIFOs and a 256B payload buffer, two 1kB read buffers and a 1kB mailbox
* passthrough mode with a 256-bit command filter, address translation and first-4B payload translation
* TPM over SPI on its own chip select, time-multiplexed with the flash and passthrough modes
* eight interrupt lines covering command upload, read buffer and TPM FIFO events

Mocha instantiates the block in [`top_chip_system.sv`][instantiation], connected to the peripheral fabric over TileLink-UL through `xbar_peri`, with the default two-port SRAM (`SramType2p`); the 1R1W variant is left out of the aggregate simulation config, see [mocha issue #271][issue 271].

The block-level DV is vendored in from OpenTitan.
The DV environment reuses the CIP-based UVM infrastructure from OpenTitan.
Mocha applies three patches ([0001_Fix_Paths.patch][], [0002_update_sim_cfg.patch][] and [0003_default_tool_sim_cfg.patch][]) to adjust file paths, the imported test lists and the default simulator; no RTL logic is modified.

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
| Documentation | DV_DOC_DRAFT_COMPLETED             | Done   | [SPI device DV document][] describes the goals, testbench architecture, stimulus, coverage, and checking strategy |
| Documentation | TESTPLAN_COMPLETED                 | Done   | [SPI device testplan][] defines the V1 smoke test and post-V1 functional, error, performance and stress testpoints |
| Testbench     | TB_TOP_CREATED                     | Done   | [tb.sv][] instantiates clock and reset, TileLink, the upstream and passthrough SPI, interrupt and alert interfaces along <br/> with the SPI device DUT |
| Testbench     | PRELIMINARY_ASSERTION_CHECKS_ADDED | Done   | [spi_device_bind.sv][] binds the TLUL protocol and CSR assertions; the SPI device RTL checks that outputs are known <br/> after reset |
| Integration   | PRE_VERIFIED_SUB_MODULES_V1        | Waived | SPI device and its primitive submodules are vendored from OpenTitan, where SPI device reached V2S <br/> ([OpenTitan SPI device checklist][]); Mocha applies no functional changes |
| Review        | DESIGN_SPEC_REVIEWED               | Waived | The specification was reviewed through the OpenTitan sign-off process and the block was imported without functional <br/> changes |
| Review        | TESTPLAN_REVIEWED                  | Done   | The vendored [OpenTitan SPI device checklist][] records the testplan review as complete |
| Review        | STD_TEST_CATEGORIES_PLANNED        | Done   | Error scenarios, performance, command filtering, upload and stress tests are covered in the [SPI device testplan][]; <br/> security countermeasures are captured in the sec_cm testplan, but V2S is not used in Mocha; power and debug are N/A |
| Simulation    | SIM_TB_ENV_CREATED                 | Done   | CIP-based UVM environment with two SPI agents (upstream host and passthrough device) and scoreboard |
| Tests         | SIM_SMOKE_TEST_PASSING             | Done   | `spi_device_flash_and_tpm`: 1/1 passed with Xcelium on August 20, 2026 at commit `32818cb` |
| Regression    | SIM_SMOKE_REGRESSION_SETUP         | Done   | `smoke` regression in `base_sim_cfg.hjson` selects `spi_device_flash_mode`; the aggregate Mocha config imports the <br/> SPI device simulation config |
| Regression    | SIM_NIGHTLY_REGRESSION_SETUP       | Done   | SPI device is included in `mocha_sim_cfgs.hjson`; results are published on the [COSMIC reports dashboard][] |
| Coverage      | SIM_COVERAGE_MODEL_ADDED           | Done   | Block-level coverage is in `spi_device_env_cov.sv` |
| Tests         | FPV_MAIN_ASSERTIONS_PROVEN         | N/A    | This V1 sign-off uses simulation; TLUL and CSR assertions are enabled in the simulation testbench |
| Regression    | FPV_REGRESSION_SETUP               | N/A    | No SPI device FPV regression is configured in Mocha |

### V2

*Checklist to be defined — see [stages.md][verification stages].*

### V3

*Checklist to be defined — see [stages.md][verification stages].*

<!-- External references -->
[COSMIC reports dashboard]: https://dashboard.reports.lowrisc.org/cosmic/mocha/dashboard.html
[OpenTitan SPI device checklist]: ../../hw/vendor/lowrisc_ip/ip/spi_device/doc/checklist.md
[OpenTitan hash]: https://github.com/lowRISC/opentitan/tree/bf4a2b24e41742151cfce9c4041e959a3ba76ca3
[issue 271]: https://github.com/lowRISC/mocha/issues/271

<!-- Stages and checklists -->
[stages]: stages.md
[design stages]: stages.md#design-stages
[verification stages]: stages.md#verification-stages
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[V1 checklist]: stages.md#v1-verification-sign-off-checklist

<!-- Commit anchors -->
<!-- Replace the d1-commit hash once SPI device D1 sign-off happens. -->
[d1-commit]: https://github.com/lowRISC/mocha/commit/1234def
[v1-commit]: https://github.com/lowRISC/mocha/commit/32818cb34909922f6aca375d61758ae63aa3e7da

<!-- Local file references -->
[block doc]: ../../hw/vendor/lowrisc_ip/ip/spi_device/README.md
[instantiation]: ../../hw/top_chip/rtl/top_chip_system.sv#L933
[SPI device DV document]: ../../hw/vendor/lowrisc_ip/ip/spi_device/dv/README.md
[SPI device testplan]: ../../hw/vendor/lowrisc_ip/ip/spi_device/data/spi_device_testplan.hjson
[tb.sv]: ../../hw/vendor/lowrisc_ip/ip/spi_device/dv/tb/tb.sv
[spi_device_bind.sv]: ../../hw/vendor/lowrisc_ip/ip/spi_device/dv/sva/spi_device_bind.sv
[0001_Fix_Paths.patch]: ../../hw/vendor/patches/lowrisc_ip/spi_device/0001_Fix_Paths.patch
[0002_update_sim_cfg.patch]: ../../hw/vendor/patches/lowrisc_ip/spi_device/0002_update_sim_cfg.patch
[0003_default_tool_sim_cfg.patch]: ../../hw/vendor/patches/lowrisc_ip/spi_device/0003_default_tool_sim_cfg.patch
