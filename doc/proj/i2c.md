# I2C

The I2C in Mocha is imported from OpenTitan.
The documentation for the hardware IP block is located [in the vendored HW directory tree][block doc].
The block can be programmed in both controller and target modes.
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

*Not yet started - see [stages.md][verification stages].*

### V2

*Checklist to be defined - see [stages.md][verification stages].*

### V3

*Checklist to be defined - see [stages.md][verification stages].*

[block doc]: ../../hw/vendor/lowrisc_ip/ip/i2c/README.md
[stages]: stages.md
[missing asserts]: https://github.com/lowRISC/mocha/issues/708
[design stages]: stages.md#hardware-ip-block-design-stages
[verification stages]: stages.md#hardware-ip-block-verification-stages
[OpenTitan hash]: https://github.com/lowRISC/opentitan/tree/bf4a2b24e41742151cfce9c4041e959a3ba76ca3
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[d1-commit]: https://github.com/lowRISC/mocha/commit/8ac5ce9d1e2af59bc12b834f7870e5a797a824a1
[registers]: ../../hw/vendor/lowrisc_ip/ip/i2c/doc/registers.md
[output asserts]: https://github.com/lowRISC/mocha/blob/8ac5ce9d1e2af59bc12b834f7870e5a797a824a1/hw/vendor/lowrisc_ip/ip/i2c/rtl/i2c.sv#L157-L181
[ot checklist]: ../../hw/vendor/lowrisc_ip/ip/i2c/doc/checklist.md
[patch]: ../../hw/vendor/patches/lowrisc_ip/i2c/0001-Fix-Paths-and-Tool.patch
