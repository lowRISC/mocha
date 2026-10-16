# SPI host

The SPI host in Mocha is imported from OpenTitan.
The documentation for the hardware IP block is located [in the vendored HW directory tree][block doc].
It drives remote SPI devices, primarily serial NOR flash, and supports standard, dual and quad commands with separate receive and transmit FIFOs.
The `NumCS` parameter sets the number of chip select lines, which Mocha configures as one.
The [vendor patch][patch] only fixes DV paths; no RTL is modified.

The rest of this document contains the design checklist for the SPI host hardware IP block for the CHERI Mocha top.
For more details on the stages and the current state for each block, please refer to the [stages documentation][stages].

## Design sign-offs

### D1

The SPI host used for D1 sign-off is the one imported from OpenTitan at revision [`bf4a2b2`][OpenTitan hash], which carries version 3.0.0 of the block, reset to D0/V0 upstream in [`91944c5`][OpenTitan stage reset].
The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].
This sign-off is based on commit [`b597321`][d1-commit].

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | [SPI host specification][block doc].
| Documentation | CSR_DEFINED                | Done   | [SPI host registers][registers].
| RTL           | CLKRST_CONNECTED           | Done   | Modules containing submodules checked: `spi_host.sv`, `spi_host_core.sv`, `spi_host_fsm.sv`, `spi_host_command_queue.sv`, `spi_host_data_fifos.sv`, `spi_host_shift_register.sv`, `spi_host_byte_select.sv`, `spi_host_byte_merge.sv`, `spi_host_window.sv` and `spi_host_reg_top.sv`. Modules without clocks and resets are confirmed to be purely combinational: `prim_onehot_enc`, `prim_subreg_ext`, `tlul_cmd_intg_chk` and `tlul_rsp_intg_gen`. The shared `prim_*` and `tlul_*` submodules are covered by their own OpenTitan sign-offs and are not walked here.
| RTL           | IP_TOP                     | Done   | This module is defined in `spi_host.sv`.
| RTL           | IP_INSTANTIABLE            | Done   | It is instantiated in top chip system.
| RTL           | PHYSICAL_MACROS_DEFINED_80 | Done   | No memory macros or analogue components. The receive and transmit FIFOs are flop-based.
| RTL           | FUNC_IMPLEMENTED           | Done   | All functionality already implemented.
| RTL           | ASSERT_KNOWN_ADDED         | Done   | Output assertions are [here][output asserts] and cover every output except `passthrough_o`, which is a direct wire from the `cio_sd_i` pin and so may legitimately be undefined. Upstream excludes it deliberately, checking connectivity with `PassthroughConn_A` instead of knownness.
| Code Quality  | LINT_SETUP                 | Done   | Verilator lint target with `-Wall` in `spi_host.core` and in the top. The block lints clean with no warnings in its own RTL.

### D2

*Checklist to be defined - see [stages.md][design stages].*

### D3

*Checklist to be defined - see [stages.md][design stages].*

## Verification sign-offs

### V1

All checklist items refer to the [V1 verification sign-off checklist][V1 checklist].
This sign-off is based on commit [`b597321`][v1-commit].

| Type          | Item                               | Status | Note/Collaterals |
|---------------|------------------------------------|--------|------------------|
| Documentation | DV_DOC_DRAFT_COMPLETED             | Done   | [SPI host DV document][] describes the goals, testbench architecture, stimulus, coverage, and checking strategy |
| Documentation | TESTPLAN_COMPLETED                 | Done   | [SPI host testplan][] defines the V1 smoke test and post-V1 functional, error, performance and stress testpoints |
| Testbench     | TB_TOP_CREATED                     | Done   | [tb.sv][] instantiates clock and reset, TileLink, SPI, pass-through, interrupt and alert interfaces along with the SPI host DUT |
| Testbench     | PRELIMINARY_ASSERTION_CHECKS_ADDED | Done   | [spi_host_bind.sv][] binds the TLUL protocol and CSR assertions; the SPI host RTL checks that outputs are known after reset |
| Integration   | PRE_VERIFIED_SUB_MODULES_V1        | Waived | The submodules are shared OpenTitan primitives and TileLink adapters (`prim_fifo_sync`, `prim_packer_fifo`, `prim_subreg`, `tlul_adapter_reg`, `tlul_socket_1n`, etc.), unmodified in Mocha. Only `prim_fifo_sync` is verified standalone upstream, through FPV. The rest are covered through the IPs that instantiate them, so none carries an independent V1 sign-off |
| Review        | DESIGN_SPEC_REVIEWED               | Done   | The specification was reviewed against the vendored 3.0.0 RTL for this sign-off. The register layout in [registers][] and the [interfaces][] table match the RTL. The [theory of operation][theory], the [programmer's guide][pguide] and some [registers][] descriptions are stale at the vendored revision: they still describe `CONFIGOPTS` as a multi-register with one entry per chip select, where 3.0.0 has a single register, and `CONTROL.SW_RST` still mentions CDC FIFOs that 3.0.0 does not have. This was corrected upstream in [`d68b4df`][OpenTitan doc fix] and will reach Mocha on the next re-vendor, tracked by [issue #752][revendor issue]. RACL is documented only in the interfaces table, and is tied off in Mocha at the [instantiation][racl tie-off] |
| Review        | TESTPLAN_REVIEWED                  | Done   | The [SPI host testplan][] was reviewed against the vendored 3.0.0 register set for this sign-off. Its V1 testpoints, `smoke` plus the six imported CSR testpoints and the two imported memory testpoints, apply as written. V2 gaps are tracked in [issue #753][testplan issue] |
| Review        | STD_TEST_CATEGORIES_PLANNED        | Done   | Error scenarios, performance, overflow, stall and stress tests are covered in the [SPI host testplan][]; security bus-integrity testing is currently out of scope for Mocha; power and debug are N/A |
| Simulation    | SIM_TB_ENV_CREATED                 | Done   | CIP-based UVM environment with SPI agent and scoreboard |
| Tests         | SIM_SMOKE_TEST_PASSING             | Done   | All V1 testpoints (`spi_host_smoke`, the five CSR tests, `spi_host_csr_mem_rw_with_rand_reset`, `spi_host_mem_walk` and `spi_host_mem_partial_access`): 40/40 passed, 5 seeds each, with Xcelium on October 2, 2026 at commit `b597321` |
| Regression    | SIM_SMOKE_REGRESSION_SETUP         | Done   | `smoke` regression in `spi_host_sim_cfg.hjson` selects `spi_host_smoke`; the aggregate Mocha config imports the SPI host simulation config |
| Regression    | SIM_NIGHTLY_REGRESSION_SETUP       | Done   | SPI host is included in `mocha_sim_cfgs.hjson`; results are published on the [COSMIC reports dashboard][] |
| Coverage      | SIM_COVERAGE_MODEL_ADDED           | Done   | Block-level coverage is in `spi_host_env_cov.sv` |
| Tests         | FPV_MAIN_ASSERTIONS_PROVEN         | N/A    | This V1 sign-off uses simulation; TLUL and CSR assertions are enabled in the simulation testbench |
| Regression    | FPV_REGRESSION_SETUP               | N/A    | No SPI host FPV regression is configured in Mocha |

### V2

*Checklist to be defined - see [stages.md][verification stages].*

### V3

*Checklist to be defined - see [stages.md][verification stages].*

[block doc]: ../../hw/vendor/lowrisc_ip/ip/spi_host/README.md
[stages]: stages.md
[design stages]: stages.md#hardware-ip-block-design-stages
[verification stages]: stages.md#hardware-ip-block-verification-stages
[OpenTitan hash]: https://github.com/lowRISC/opentitan/tree/bf4a2b24e41742151cfce9c4041e959a3ba76ca3
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[V1 checklist]: stages.md#v1-verification-sign-off-checklist
[d1-commit]: https://github.com/lowRISC/mocha/commit/b5973217f704923917e7761f73df7dfcb8d0c345
[v1-commit]: https://github.com/lowRISC/mocha/commit/b5973217f704923917e7761f73df7dfcb8d0c345
[pguide]: ../../hw/vendor/lowrisc_ip/ip/spi_host/doc/programmers_guide.md
[testplan issue]: https://github.com/lowRISC/mocha/issues/753
[OpenTitan stage reset]: https://github.com/lowRISC/opentitan/commit/91944c566bc8b5315204552ab24940b7484a1823
[theory]: ../../hw/vendor/lowrisc_ip/ip/spi_host/doc/theory_of_operation.md
[interfaces]: ../../hw/vendor/lowrisc_ip/ip/spi_host/doc/interfaces.md
[OpenTitan doc fix]: https://github.com/lowRISC/opentitan/commit/d68b4dfd0899388271f0a20743c53c7992cacc3b
[revendor issue]: https://github.com/lowRISC/mocha/issues/752
[racl tie-off]: https://github.com/lowRISC/mocha/blob/b5973217f704923917e7761f73df7dfcb8d0c345/hw/top_chip/rtl/top_chip_system.sv#L996-L997
[registers]: ../../hw/vendor/lowrisc_ip/ip/spi_host/doc/registers.md
[output asserts]: https://github.com/lowRISC/mocha/blob/b5973217f704923917e7761f73df7dfcb8d0c345/hw/vendor/lowrisc_ip/ip/spi_host/rtl/spi_host.sv#L637-L652
[patch]: ../../hw/vendor/patches/lowrisc_ip/spi_host/0001_Sim_Path_Fixes.patch
[SPI host DV document]: ../../hw/vendor/lowrisc_ip/ip/spi_host/dv/README.md
[SPI host testplan]: ../../hw/vendor/lowrisc_ip/ip/spi_host/data/spi_host_testplan.hjson
[tb.sv]: ../../hw/vendor/lowrisc_ip/ip/spi_host/dv/tb.sv
[spi_host_bind.sv]: ../../hw/vendor/lowrisc_ip/ip/spi_host/dv/sva/spi_host_bind.sv
[COSMIC reports dashboard]: https://dashboard.reports.lowrisc.org/cosmic/mocha/dashboard.html
