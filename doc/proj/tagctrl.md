# Tag Controller

The tag controller in Mocha is imported from Capabilities Limited's tag controller [repository][axi_cheri_tagcontroller] at revision [`173646d`][tagctrl hash].
The documentation for the hardware IP block is provided as part of the upstream repository under [`/docs/tag_controller.adoc`][tagctrl_doc].
A newer HPDCache-based version of the tag controller with a hierarchical tag table is available and will be integrated in mocha in an upcoming release.

The rest of this document contains the design checklist for the Tag Controller hardware IP block for the CHERI Mocha top.
For more details on the stages and the current state for each block, please refer to the [stages documentation][stages].

## Design sign-offs

### D1

This sign-off is based on commit [`90741aa`][d1-commit].

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | The High-Level Overview in [`/docs/tag_controller.adoc`][tagctrl_doc] applies to the vendored revision, and the cache behaviour is documented in the PULP LLC's [`axi_llc.md`][llc doc]. The rest of that document postdates `173646d` and describes the newer [HPDCache](https://github.com/Capabilities-Limited/cv-hpdcache)-based version: its Unconfigured, Zeroing, Serving and Flushing states, entered through start, resume and stop commands on the config port, do not exist here, where the only FSM is the LLC flush FSM in `axi_tagctrl_config.sv`.
| Documentation | CSR_DEFINED                | Done   | The registers as built are the 18 defined in the PULP LLC's [`axi_llc_regs.hjson`][llc regs], instantiated through `axi_llc_reg_top` in `axi_tagctrl_reg_wrap.sv`: `CFG_SPM_LOW`/`CFG_SPM_HIGH` and `CFG_FLUSH_LOW`/`CFG_FLUSH_HIGH` are read-write, `COMMIT_CFG` is `rw1s`, and the remaining 13 are read-only. Mocha ties `conf_req_i` to `'0` at the [instantiation][conf tie-off], so software cannot reach any of them. The [Programmer’s Model & Software Interface][tag_ctrl_doc_progmod] section of the upstream document describes the newer tag controller's interface instead, and is to be reconciled when that version is integrated.
| RTL           | CLKRST_CONNECTED           | Done   | The clock and reset are driven into the toplevel from [`top_chip_system.sv`][instantiation]. Modules containing submodules checked: `axi_tagctrl_reg_wrap.sv`, `axi_tagctrl_top.sv`, `axi_tagctrl_config.sv`, `axi_tagctrl_r.sv`, `axi_tagctrl_w.sv`, `axi_tagc_read_unit.sv`, `axi_tagc_write_unit.sv`, `axi_tagctrl_data_way.sv`, `axi_tagctrl_ways.sv`, `axi_llc_tag_store.sv`, `eviction_refill/axi_llc_r_master.sv`, `axi_llc_hit_miss.sv`, `axi_llc_evict_unit.sv`, `axi_llc_refill_unit.sv` and `axi_llc_merge_unit.sv`. `axi_tagctrl_ax.sv` takes a clock and reset and instantiates nothing further. Modules without clocks and resets are confirmed to be purely combinational: `axi_id_prepend`, `lzc`, `onehot_to_bin`, `prim_subreg_arb`, `stream_demux` and `sub_per_hash`.
| RTL           | IP_TOP                     | Done   | The tag controller's toplevel module is defined in [`/hw/vendor/tagctrl/src/axi_tagctrl_reg_wrap.sv`](/hw/vendor/tagctrl/src/axi_tagctrl_reg_wrap.sv)
| RTL           | IP_INSTANTIABLE            | Done   | The tag controller's toplevel module is instantiated in [`/hw/top_chip/rtl/top_chip_system.sv`](/hw/top_chip/rtl/top_chip_system.sv).
| RTL           | PHYSICAL_MACROS_DEFINED_80 | Done   | The macros as instantiated are all `prim_ram_1p`, fixed by the `SetAssociativity` of 8, `NumLines` of 128 and `NumBlocks` of 4 at the top: eight data macros of 512 entries by 64 bits in `axi_tagctrl_data_way.sv`, and eight tag macros of 128 entries by 54 bits in `axi_llc_tag_store.sv`, totalling 32 KiB of data and 6.75 KiB of tag storage. The new hierarchical tag controller is expected to be 6 KiB instead (4 KiB leaf cache, 2 KiB directory/root cache); any synthesis flow run after it is integrated must substitute those sizes to get an accurate area.
| RTL           | FUNC_IMPLEMENTED           | Done   | The tag controller's functionality is implemented. Tagged requests can be served, and the tag controller can effectively bridge between a tag aware memory subsystem and a tag unaware one. The tag controller from commit [`173646d`][tagctrl hash] was used to successfully boot cheriBSD on the Genesys2 board, on the COREV_APU platform. Planned improvements exist, specifically in the recent HPDCache-based version of the tag controller.
| RTL           | ASSERT_KNOWN_ADDED         | Done   | Assertion that the output of the toplevel module are known were added to [`/hw/vendor/tagctrl/src/axi_tagctrl_reg_wrap.sv`](/hw/vendor/tagctrl/src/axi_tagctrl_reg_wrap.sv).
| Code Quality  | LINT_SETUP                 | Done   | Verilator warning waivers are added to [`/hw/top_chip/lint/top_chip_system.vlt`](/hw/top_chip/lint/top_chip_system.vlt#L150) tag controller and the PULP LLC. The Lint setup will need updating before D2 which is tracked in [this issue](https://github.com/lowRISC/mocha/issues/742).

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

[axi_cheri_tagcontroller]: https://github.com/Capabilities-Limited/axi_cheri_tagcontroller
[d1-commit]: https://github.com/lowRISC/mocha/commit/90741aa2d21ec78b3de4a35809176dcf96c3315d
[instantiation]: ../../hw/top_chip/rtl/top_chip_system.sv#L1301-L1302
[conf tie-off]: ../../hw/top_chip/rtl/top_chip_system.sv#L1308
[llc doc]: ../../hw/vendor/pulp_axi_llc/doc/axi_llc.md
[llc regs]: ../../hw/vendor/pulp_axi_llc/data/axi_llc_regs.hjson
[stages]: stages.md
[design stages]: stages.md#hardware-ip-block-design-stages
[verification stages]: stages.md#hardware-ip-block-verification-stages
[tagctrl hash]: https://github.com/Capabilities-Limited/axi_cheri_tagcontroller/tree/173646d5947d09bcb27f6ae3817ae7f6d3c1f6a9
[tagctrl_doc]: https://github.com/Capabilities-Limited/axi_cheri_tagcontroller/blob/ea82870f2619bd092d4f7b52ef66513f67fa8e35/docs/tag_controller.adoc
[tag_ctrl_doc_progmod]: https://github.com/Capabilities-Limited/axi_cheri_tagcontroller/blob/ea82870f2619bd092d4f7b52ef66513f67fa8e35/docs/tag_controller.adoc#5-programmers-model--software-interface
