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

The SPI host used for D1 sign-off is the one imported from OpenTitan at revision [`bf4a2b2`][OpenTitan hash], where it was signed off at D1 in [this pull request][OpenTitan D1 sign-off].
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

*Checklist to be defined — see [stages.md][design stages].*

### D3

*Checklist to be defined — see [stages.md][design stages].*

## Verification sign-offs

### V1

*Not yet started — see [stages.md][verification stages].*

### V2

*Checklist to be defined — see [stages.md][verification stages].*

### V3

*Checklist to be defined — see [stages.md][verification stages].*

[block doc]: ../../hw/vendor/lowrisc_ip/ip/spi_host/README.md
[stages]: stages.md
[design stages]: stages.md#design-stages
[verification stages]: stages.md#verification-stages
[OpenTitan hash]: https://github.com/lowRISC/opentitan/tree/bf4a2b24e41742151cfce9c4041e959a3ba76ca3
[OpenTitan D1 sign-off]: https://github.com/lowRISC/opentitan/pull/6762
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[d1-commit]: https://github.com/lowRISC/mocha/commit/b5973217f704923917e7761f73df7dfcb8d0c345
[registers]: ../../hw/vendor/lowrisc_ip/ip/spi_host/doc/registers.md
[output asserts]: https://github.com/lowRISC/mocha/blob/b5973217f704923917e7761f73df7dfcb8d0c345/hw/vendor/lowrisc_ip/ip/spi_host/rtl/spi_host.sv#L637-L652
[patch]: ../../hw/vendor/patches/lowrisc_ip/spi_host/0001_Sim_Path_Fixes.patch
