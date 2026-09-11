# SPI device

The SPI device in Mocha is imported from OpenTitan.
The documentation for the hardware IP block is located [in the vendored HW directory tree][block doc].
The SPI device emulates a serial NOR flash towards an external host, can pass transactions through to a downstream flash device, and carries a TPM interface on its own chip select.
Mocha instantiates it with no parameter overrides: the passthrough port is unconnected and `passthrough_i` tied to its package default, alerts and RACL are tied off with `alert_tx_o` and `racl_error_o` unconnected and `EnableRacl` left at 0, the RAM configuration inputs take `RAM_2P_CFG_DEFAULT` with their responses and `sck_monitor_o` unconnected, and the MBIST and scan inputs are tied off.
Flash passthrough, alerts and RACL are therefore out of scope for Mocha; the flash emulation and TPM interfaces are the integrated ones.
The block spans two clock domains, the system clock and the incoming SPI clock, so its submodules take clocks and resets named for the domain they belong to in addition to the usual `clk_i` and `rst_ni`; only `spid_dpram` and `spid_addr_4b` drop `clk_i` and `rst_ni` entirely.
Mocha instantiates it with the default two-port SRAM, `SramType2p`.
This will be switched to the 1r1w variant as per [issue #271][sram type].
The [vendor patches][patch] adjust testplan and simulation config paths and the default simulator; the only RTL change adds the output known assertions listed below.

The rest of this document contains the design checklist for the SPI device hardware IP block for the CHERI Mocha top.
For more details on the stages and the current state for each block, please refer to the [stages documentation][stages].

## Design sign-offs

### D1

The SPI device used for [D1 sign-off][OpenTitan D1 signoff] is the one imported from OpenTitan at revision [`bf4a2b2`][OpenTitan hash], where the [upstream checklist][OpenTitan spi_device checklist] records the block past D2S and V2S.
The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].
This sign-off is based on commit [`55fa175`][d1-commit].

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | [SPI device specification][block doc].
| Documentation | CSR_DEFINED                | Done   | [SPI device registers][registers].
| RTL           | CLKRST_CONNECTED           | Done   | Modules containing submodules checked: `spi_device.sv`, `spi_readcmd.sv`, `spi_passthrough.sv`, `spi_tpm.sv`, `spid_dpram.sv`, `spid_readsram.sv`, `spid_readbuffer.sv`, `spid_status.sv`, `spid_upload.sv`, `spid_addr_4b.sv`, `spid_csb_sync.sv` and `spi_device_reg_top.sv`. Modules without clocks and resets are confirmed to be purely combinational: `prim_buf`, `prim_onehot_enc`, `prim_slicer`, `prim_subreg_ext`, `tlul_cmd_intg_chk` and `tlul_rsp_intg_gen`. The shared `prim_*` and `tlul_*` submodules are covered by their own OpenTitan sign-offs and are not walked here. The domain assignment was checked at each instance, not only the connection: `clk_spi_in_buf`/`rst_spi_in_n` reach the input-domain ports, `clk_spi_out_buf`/`rst_spi_out_n` the `clk_out_i`/`rst_out_ni` ports, `clk_csb` the `clk_csb_i` ports of `spid_status` and `spid_upload`, and `clk_i`/`rst_ni` the `sys_clk_i`/`sys_rst_ni` ports, with `spi_tpm` on its own TPM resets.
| RTL           | IP_TOP                     | Done   | This module is defined in `spi_device.sv`.
| RTL           | IP_INSTANTIABLE            | Done   | It is instantiated in top chip system with no parameter overrides; the unconnected outputs and tied-off inputs are listed in the introduction.
| RTL           | PHYSICAL_MACROS_DEFINED_80 | Done   | The buffers share one dual-port RAM instantiated through `prim_ram_2p_async_adv` in `spid_dpram.sv`, fixed at 1024 entries of 32 bits. This becomes a one-read-one-write RAM under [issue #271][sram type].
| RTL           | FUNC_IMPLEMENTED           | Done   | All functionality already implemented.
| RTL           | ASSERT_KNOWN_ADDED         | Done   | Output assertions are [here][output asserts] and cover every output except `cio_sd_o` and `passthrough_o.s`, which carry SPI-domain data that is legitimately undefined outside a transaction. Upstream takes the same view for `cio_sd_o`, checking `cio_sd_en_o` instead and asserting that the block does not drive the pads while both chip selects are inactive. The other six `passthrough_o` fields are checked. `tl_o` and `racl_error_o` are checked on their handshake and valid fields, as elsewhere. `passthrough_o.s` could instead be checked qualified on `s_en`; the passthrough port is unconnected in Mocha, so nothing turns on it here.
| Code Quality  | LINT_SETUP                 | Done   | Verilator lint target with `-Wall` in `spi_device.core` and in the top. Width, unused signal and unoptimisable-flat warnings in `spi_device_pkg.sv`, `spi_tpm.sv`, `spid_status.sv` and `spi_readcmd.sv` [are waived][lint waivers]. The block target also loads the vendored `lint/spi_device.vlt`, which waives a reserved-word warning in `spi_device_reg_pkg.sv` and a width warning in `spid_fifo2sram_adapter.sv`. The block carries vendored waivers for the other lint tools too — `lint/spi_device.waiver` and `lint/spi_tpm.waiver` for AscentLint and `lint/spi_device.vbl` for Verible — but neither tool is run in Mocha.

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

[block doc]: ../../hw/vendor/lowrisc_ip/ip/spi_device/README.md
[stages]: stages.md
[design stages]: stages.md#design-stages
[verification stages]: stages.md#verification-stages
[OpenTitan hash]: https://github.com/lowRISC/opentitan/tree/bf4a2b24e41742151cfce9c4041e959a3ba76ca3
[OpenTitan D1 signoff]: https://github.com/lowRISC/opentitan/pull/898
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[d1-commit]: https://github.com/lowRISC/mocha/commit/55fa1759f16937343678b01ada783c990492825a
[registers]: ../../hw/vendor/lowrisc_ip/ip/spi_device/doc/registers.md
[output asserts]: https://github.com/lowRISC/mocha/blob/55fa1759f16937343678b01ada783c990492825a/hw/vendor/lowrisc_ip/ip/spi_device/rtl/spi_device.sv#L1958-L1988
[OpenTitan spi_device checklist]: ../../hw/vendor/lowrisc_ip/ip/spi_device/doc/checklist.md
[lint waivers]: ../../hw/top_chip/lint/top_chip_system.vlt
[patch]: ../../hw/vendor/patches/lowrisc_ip/spi_device
[sram type]: https://github.com/lowRISC/mocha/issues/271
