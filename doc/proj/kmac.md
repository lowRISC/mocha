# KMAC

The KMAC in Mocha is imported from OpenTitan.
The documentation for the hardware IP block is located [in the vendored HW directory tree][block doc].
Mocha instantiates it only to check the ROM contents at boot: masking is disabled and the register, key manager, EDN, life cycle and interrupt interfaces are unused; their inputs are tied off to their respective package default values and their outputs are left unconnected.
[One patch][keymgr edn patch] declares the sideload key and EDN types in `kmac_pkg` to drop the `keymgr_pkg` and `edn_pkg` dependencies; the logic is unchanged.

The rest of this document contains the design checklist for the KMAC hardware IP block for the CHERI Mocha top.

## Design sign-offs

### D1

The KMAC used for D1 sign-off is the one imported from OpenTitan at revision [bf4a2b2][OpenTitan hash].
The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].
This sign-off is based on commit [3824b31][d1-commit].

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | [KMAC specification][block doc].
| Documentation | CSR_DEFINED                | Done   | [KMAC registers][registers].
| RTL           | CLKRST_CONNECTED           | Done   | Modules containing submodules checked: `kmac.sv`, `kmac_core.sv`, `kmac_app.sv`, `kmac_entropy.sv`, `kmac_errchk.sv`, `kmac_msgfifo.sv`, `kmac_staterd.sv`, `kmac_reg_top.sv`, `sha3.sv`, `sha3pad.sv`, `keccak_round.sv` and `keccak_2share.sv`. Modules without clocks and resets are confirmed to be purely combinational: `prim_sec_anchor_buf`, `prim_slicer`, `prim_subreg_ext`, `tlul_cmd_intg_chk` and `tlul_rsp_intg_gen`.
| RTL           | IP_TOP                     | Done   | This module is defined in `kmac.sv`.
| RTL           | IP_INSTANTIABLE            | Done   | It is instantiated in top chip system.
| RTL           | PHYSICAL_MACROS_DEFINED_80 | Done   | No memory macros or analogue components. The FIFO depths are fixed.
| RTL           | FUNC_IMPLEMENTED           | Done   | All functionality already implemented. Mocha exercises only the unmasked application interface path.
| RTL           | ASSERT_KNOWN_ADDED         | Done   | Output assertions are [here][output asserts] and cover every output.
| Code Quality  | LINT_SETUP                 | Done   | Verilator lint target with `-Wall` in `kmac.core` and in the top. The hidden enum value and circular combinational logic warnings [are waived][lint waivers]; the unused clock and width warnings are waived [in the block][block waivers].

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

[block doc]: ../../hw/vendor/lowrisc_ip/ip/kmac/README.md
[missing asserts]: https://github.com/lowRISC/mocha/issues/707
[design stages]: stages.md#hardware-ip-block-design-stages
[verification stages]: stages.md#hardware-ip-block-verification-stages
[OpenTitan hash]: https://github.com/lowRISC/opentitan/tree/bf4a2b24e41742151cfce9c4041e959a3ba76ca3
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[d1-commit]: https://github.com/lowRISC/mocha/commit/3824b3167f3691f0a0259f2d85c43b022ac56c1a
[registers]: ../../hw/vendor/lowrisc_ip/ip/kmac/doc/registers.md
[output asserts]: https://github.com/lowRISC/mocha/blob/3824b3167f3691f0a0259f2d85c43b022ac56c1a/hw/vendor/lowrisc_ip/ip/kmac/rtl/kmac.sv#L1531-L1540
[ot checklist]: ../../hw/vendor/lowrisc_ip/ip/kmac/doc/checklist.md
[lint waivers]: ../../hw/top_chip/lint/top_chip_system.vlt
[block waivers]: ../../hw/vendor/lowrisc_ip/ip/kmac/lint/kmac.vlt
[keymgr edn patch]: ../../hw/vendor/patches/lowrisc_ip/kmac/0001-Remove-keymgr-edn-deps.patch
