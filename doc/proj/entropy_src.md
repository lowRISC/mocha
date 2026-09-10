# Entropy source

The Entropy source in Mocha is imported from OpenTitan.
The documentation for the hardware IP block is located [in the vendored HW directory tree][block doc].
The block is parameterised for Mocha in [top_pkg.sv][top_pkg]: a 16-bit noise source bus, a 20-bit health test window, and entropy and distribution FIFO depths of 3 and 11 respectively.
The OTP firmware read and override controls are tied true, and the hardware entropy and external health test interfaces are unused, so entropy is consumed by firmware over TileLink.
The [vendor patches][patch] only drop the `otp_ctrl_pkg` dependency from the core file and fix DV paths; no RTL is modified.

The rest of this document contains the design checklist for the Entropy source hardware IP block for the CHERI Mocha top.
For more details on the stages and the current state for each block, please refer to the [stages documentation][stages].

## Design sign-offs

### D1

The Entropy source used for D1 sign-off is the one imported from OpenTitan at revision [bf4a2b2][OpenTitan hash], where it was [signed off at D1][OpenTitan D1 sign-off].
The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].
This sign-off is based on commit [b597321][d1-commit].

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | [Entropy source specification][block doc].
| Documentation | CSR_DEFINED                | Done   | [Entropy source registers][registers].
| RTL           | CLKRST_CONNECTED           | Done   | Modules containing submodules checked: `entropy_src.sv`, `entropy_src_core.sv`, `entropy_src_reg_top.sv`, `entropy_src_cntr_reg.sv`, `entropy_src_ack_sm.sv`, `entropy_src_main_sm.sv` and the health test modules `entropy_src_repcnt_ht.sv`, `entropy_src_repcnts_ht.sv`, `entropy_src_adaptp_ht.sv`, `entropy_src_bucket_ht.sv` and `entropy_src_markov_ht.sv`, together with the conditioner modules `sha3.sv`, `sha3pad.sv`, `keccak_round.sv` and `keccak_2share.sv`. Modules without clocks and resets are confirmed to be purely combinational: `prim_buf`, `prim_subreg_ext`, `tlul_cmd_intg_chk`, `tlul_rsp_intg_gen`, `prim_slicer` in `sha3pad.sv` and `prim_sec_anchor_buf` in `keccak_round.sv`.
| RTL           | IP_TOP                     | Done   | This module is defined in `entropy_src.sv`.
| RTL           | IP_INSTANTIABLE            | Done   | It is instantiated in top chip system.
| RTL           | PHYSICAL_MACROS_DEFINED_80 | Done   | No memory macros or analogue components. The FIFO depths are fixed and the noise source is external to the block.
| RTL           | FUNC_IMPLEMENTED           | Done   | All functionality already implemented.
| RTL           | ASSERT_KNOWN_ADDED         | Done   | Output assertions are [here][output asserts] and cover every output.
| Code Quality  | LINT_SETUP                 | Done   | Verilator lint target with `-Wall` in `entropy_src.core` and in the top. The only warnings in the block are the rng_bit_sel width expansions in the health test modules and the core, and they [are waived][lint waivers].

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

[block doc]: ../../hw/vendor/lowrisc_ip/ip/entropy_src/README.md
[stages]: stages.md
[missing asserts]: https://github.com/lowRISC/mocha/issues/713
[design stages]: stages.md#design-stages
[verification stages]: stages.md#verification-stages
[OpenTitan hash]: https://github.com/lowRISC/opentitan/tree/bf4a2b24e41742151cfce9c4041e959a3ba76ca3
[OpenTitan D1 sign-off]: https://github.com/lowRISC/opentitan/pull/4413
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[d1-commit]: https://github.com/lowRISC/mocha/commit/b5973217f704923917e7761f73df7dfcb8d0c345
[registers]: ../../hw/vendor/lowrisc_ip/ip/entropy_src/doc/registers.md
[top_pkg]: ../../hw/top_chip/rtl/top_pkg.sv
[output asserts]: ../../hw/vendor/lowrisc_ip/ip/entropy_src/rtl/entropy_src.sv#L282-L317
[ot checklist]: ../../hw/vendor/lowrisc_ip/ip/entropy_src/doc/checklist.md
[lint waivers]: ../../hw/top_chip/lint/top_chip_system.vlt
[patch]: ../../hw/vendor/patches/lowrisc_ip/entropy_src
