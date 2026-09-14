# AXI crossbar

The AXI crossbar is vendored from the PULP platform [`axi` repository][pulp axi] at revision [`a256a3b`][pulp hash], with the local patches in [`hw/vendor/patches/pulp_axi`][patches].
[`0001_Primitives_from_lowRISC_used.patch`][prim patch] modifies `axi_demux.sv`, `axi_demux_simple.sv`, `axi_mux.sv`, `axi_xbar.sv` and `axi_xbar_unmuxed.sv`, and is where the lowRISC prim modules in the CLKRST_CONNECTED row come from.
The documentation for the hardware IP block is located [in the vendored HW directory tree][block doc].
It is a fully connected AXI4 crossbar.
Mocha instantiates it in [`top_chip_system.sv`][instantiation] connecting two hosts to eight devices, with atomics passed through but not handled, and the address map that routes the ROM, SRAM, debug memory, mailbox, software-DV window, TileLink crossbar, DRAM and the rest of the chip.
D1 scope is this instance. [`chip_mocha_genesys2.sv`][genesys2 instantiation] also instantiates a one-host, one-device crossbar for Ethernet, which is not covered here.

The rest of this document contains the design checklist for the AXI crossbar hardware IP block for the CHERI Mocha top.
For more details on the stages and the current state for each block, please refer to the [stages documentation][stages].

## Design sign-offs

### D1

The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].
This sign-off is based on commit [`97816a0`][d1-commit], the last of the output known assertion commits the waiver below relies on.

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | [AXI crossbar specification][block doc], covering the parameters, ports, address map and ordering rules.
| Documentation | CSR_DEFINED                | Done   | The crossbar has no registers; it is configured entirely by parameters and the address map input.
| RTL           | CLKRST_CONNECTED           | Done   | Modules containing submodules checked: `axi_xbar` in `axi_xbar.sv`, which also declares the unused `axi_xbar_intf` wrapper, `axi_xbar_unmuxed.sv`, and below them `axi_mux`, `axi_demux`, `axi_demux_simple`, `axi_demux_id_counters` (declared in `axi_demux_simple.sv`), `axi_err_slv`, `axi_multicut`, `axi_cut`, `rr_arb_tree`, `fifo_v3`, `prim_fifo_sync`, `counter`, `delta_counter` and `prim_count`. Clocked modules that instantiate nothing further: `spill_register`, `prim_fifo_sync_cnt` (the FIFOs set `Secure` to 0) and `prim_flop`. Modules with neither clock nor reset are confirmed to be purely combinational: `addr_decode`, `axi_id_prepend` and `lzc`. `axi_atop_filter` is not built, as `axi_err_slv` instantiates it only when ATOPs are enabled.
| RTL           | IP_TOP                     | Done   | This module is defined in `axi_xbar.sv`. It has no core file of its own; it is compiled as part of the vendored `axi.core`.
| RTL           | IP_INSTANTIABLE            | Done   | It is instantiated in top chip system; the separate Genesys 2 rest-of-chip instance is outside this sign-off.
| RTL           | PHYSICAL_MACROS_DEFINED_80 | Done   | No memory macros or analogue components. The request and response buffering is flop-based.
| RTL           | FUNC_IMPLEMENTED           | Done   | All functionality already implemented. Atomics are disabled at the instantiation, meaning that they are passed through the xbar, but not explicitly handled in the xbar.
| RTL           | ASSERT_KNOWN_ADDED         | Waived | The crossbar carries whatever the attached blocks drive, so the known checks on their outputs are sufficient and crossbar-level assertions would be redundant. Assertions were proposed and rejected on this basis in [pull request #734][assertions pr].
| Code Quality  | LINT_SETUP                 | Done   | Verilator lint target with `-Wall` in `top_chip_system.core`. The blanket PULP AXI waivers in [top_chip_system.vlt][lint waivers] cover this file. They are shared with the other PULP AXI blocks and cannot be dropped on the crossbar's account. With them disabled the crossbar's own sources report only the DECLFILENAME warnings for the `axi_xbar_intf` and `axi_xbar_unmuxed_intf` wrappers declared alongside their modules. `chip_mocha_genesys2.core` has no lint target, so this evidence covers the `top_chip_system` instance only.

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

[block doc]: ../../hw/vendor/pulp_axi/doc/axi_xbar.md
[stages]: stages.md
[design stages]: stages.md#design-stages
[verification stages]: stages.md#verification-stages
[pulp axi]: https://github.com/pulp-platform/axi
[pulp hash]: https://github.com/pulp-platform/axi/tree/a256a3b86394fedf19e361047fccfdd7f6ef83e4
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[d1-commit]: https://github.com/lowRISC/mocha/commit/97816a09b4bff4fa48c12e586a0fa71a1698836e
[instantiation]: ../../hw/top_chip/rtl/top_chip_system.sv#L558
[genesys2 instantiation]: ../../hw/top_chip/rtl/chip_mocha_genesys2.sv#L545
[patches]: ../../hw/vendor/patches/pulp_axi
[prim patch]: ../../hw/vendor/patches/pulp_axi/0001_Primitives_from_lowRISC_used.patch
[assertions pr]: https://github.com/lowRISC/mocha/pull/734
[lint waivers]: ../../hw/top_chip/lint/top_chip_system.vlt#L60-L69
