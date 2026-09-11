# ROM control

The ROM control in Mocha is imported from OpenTitan.
The documentation for the hardware IP block is located [in the vendored HW directory tree][block doc].
It holds the boot ROM, descrambles its contents on the way out, and checks the ROM's integrity after reset before releasing the CPU.
Mocha instantiates it with scrambling enabled over a 32 KiB ROM, and drives the integrity check through the KMAC application interface, reporting the result to the power manager.
The [vendor patches][patch] only adjust testplan, simulation config and tool import paths, a DV core file, the ROM image scrambling script and the DV scrambler model; no RTL is modified.

The rest of this document contains the design checklist for the ROM control hardware IP block for the CHERI Mocha top.
For more details on the stages and the current state for each block, please refer to the [stages documentation][stages].

## Design sign-offs

### D1

The ROM control used for D1 sign-off is the one imported from OpenTitan at revision [`bf4a2b2`][OpenTitan hash], where it was signed off at D1 in [this pull request][OpenTitan D1 sign-off] and the [upstream checklist][OpenTitan ROM control checklist] records it past D1.
The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].
This sign-off is based on commit [`b597321`][d1-commit].

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | [ROM control specification][block doc].
| Documentation | CSR_DEFINED                | Done   | [ROM control registers][registers].
| RTL           | CLKRST_CONNECTED           | Done   | Modules containing submodules checked: `rom_ctrl.sv`, `rom_ctrl_fsm.sv`, `rom_ctrl_compare.sv`, `rom_ctrl_mux.sv`, `rom_ctrl_scrambled_rom.sv` and `rom_ctrl_regs_reg_top.sv`; `rom_ctrl_counter.sv` takes a clock and reset and instantiates no submodules. Modules without clocks and resets are confirmed to be purely combinational: `prim_buf`, `prim_sec_anchor_buf`, `prim_subreg_ext`, `prim_subst_perm`, `tlul_cmd_intg_chk` and `tlul_rsp_intg_gen`. The clocked shared submodules instantiated: `prim_alert_sender`, `prim_count`, `prim_fifo_sync`, `prim_flop`, `prim_mubi4_sender`, `prim_prince`, `prim_reg_we_check`, `prim_rom_adv`, `prim_subreg`, `tlul_adapter_reg` and `tlul_adapter_sram` have their clock and reset driven from the instantiating module and are not walked further, being covered by their own OpenTitan sign-offs.
| RTL           | IP_TOP                     | Done   | This module is defined in `rom_ctrl.sv`.
| RTL           | IP_INSTANTIABLE            | Done   | It is instantiated in top chip system.
| RTL           | PHYSICAL_MACROS_DEFINED_80 | Done   | The boot ROM is instantiated through `prim_rom_adv` in `rom_ctrl_scrambled_rom.sv`, fixed at 8192 entries of 39 bits by the 32 KiB `MemSizeRom` and scrambling being enabled. The [upstream checklist][OpenTitan ROM control checklist] records this as N/A; Mocha records it Done because the ROM macro is fixed by the Mocha configuration.
| RTL           | FUNC_IMPLEMENTED           | Done   | All functionality already implemented.
| RTL           | ASSERT_KNOWN_ADDED         | Done   | Output assertions are [here][output asserts] and cover every output.
| Code Quality  | LINT_SETUP                 | Done   | Verilator lint target with `-Wall` in `rom_ctrl.core` and in the top. The block target's own `lint/rom_ctrl.vlt` is empty; the unused signal, undriven and unoptimisable-flat warnings in `rom_ctrl.sv` [are waived][lint waivers] in the top lint flow only.

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

[block doc]: ../../hw/vendor/lowrisc_ip/ip/rom_ctrl/README.md
[stages]: stages.md
[design stages]: stages.md#design-stages
[verification stages]: stages.md#verification-stages
[OpenTitan hash]: https://github.com/lowRISC/opentitan/tree/bf4a2b24e41742151cfce9c4041e959a3ba76ca3
[OpenTitan D1 sign-off]: https://github.com/lowRISC/opentitan/pull/7114
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[d1-commit]: https://github.com/lowRISC/mocha/commit/b5973217f704923917e7761f73df7dfcb8d0c345
[registers]: ../../hw/vendor/lowrisc_ip/ip/rom_ctrl/doc/registers.md
[output asserts]: ../../hw/vendor/lowrisc_ip/ip/rom_ctrl/rtl/rom_ctrl.sv#L519-L561
[lint waivers]: https://github.com/lowRISC/mocha/blob/b5973217f704923917e7761f73df7dfcb8d0c345/hw/top_chip/lint/top_chip_system.vlt#L317-L324
[OpenTitan ROM control checklist]: ../../hw/vendor/lowrisc_ip/ip/rom_ctrl/doc/checklist.md
[patch]: ../../hw/vendor/patches/lowrisc_ip/rom_ctrl
