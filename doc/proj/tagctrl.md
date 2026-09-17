# Tag Controller

The tag controller in Mocha is imported from Capabilities Limited's tag controller [repository][axi_cheri_tagcontroller].
The documentation for the hardware IP block is provided as part of the upstream repository under [/docs/tag_controller.adoc][tagctrl_doc].
A newer HPDCache-based version of the tag controller with a hierarchical tag table is available and will be integrated in mocha in an upcoming release.

## Design sign-offs

### D1

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | The documentation and specifications of the tag controller is available in the tag controller repository under [`/docs/tag_controller.adoc`][tagctrl_doc]. It mentions the overall expected behaviour of the tag controller and describes a more recent [HPDCache](https://github.com/Capabilities-Limited/cv-hpdcache)-based version with support for advanced configuration and hierarchical tag table.
| Documentation | CSR_DEFINED                | Done   | The documentation has a [Programmer’s Model & Software Interface][tag_ctrl_doc_progmod] section describing the memory mapped configuration interface of the recent tag controller.
| RTL           | CLKRST_CONNECTED           | Done   | The `clk_i` and `rst_ni` signals are connected to the modules instantiated in: [`/hw/vendor/tagctrl/src/`](/hw/vendor/tagctrl/src/){`axi_tagctrl_reg_wrap.sv`,`axi_tagctrl_top.sv`,`axi_tagctrl_config.sv`,`axi_tagctrl_ax.sv`,`axi_tagctrl_r.sv`,`axi_tagctrl_w.sv`,`axi_tagc_read_unit.sv`,`axi_tagc_write_unit.sv`,`axi_tagctrl_data_way.sv`,`axi_tagctrl_ways.sv`,`axi_llc_tag_store.sv`}. The `clk_i` and `rst_ni` signals are passed to the tag controller's toplevel module from `/hw/top_chip/rtl/top_chip_system.sv`.
| RTL           | IP_TOP                     | Done   | The tag controller's toplevel module is defined in [`/hw/vendor/tagctrl/src/axi_tagctrl_reg_wrap.sv`](/hw/vendor/tagctrl/src/axi_tagctrl_reg_wrap.sv)
| RTL           | IP_INSTANTIABLE            | Done   | The tag controller's toplevel module is instantiated in [`/hw/top_chip/rtl/top_chip_system.sv`](/hw/top_chip/rtl/top_chip_system.sv).
| RTL           | PHYSICAL_MACROS_DEFINED_80 | TODO   | ...
| RTL           | FUNC_IMPLEMENTED           | Done   | The tag controller's functionality is implemented. Tagged requests can be served, and the tag controller can effectively bridge between a tag aware memory subsystem and a tag unaware one. The tag controller was successfully used in booting the cheriBSD capability operating system. Planned improvements exist, specifically in the recent HPDCache-based version of the tag controller.
| RTL           | ASSERT_KNOWN_ADDED         | DONE   | Assertion that the output of the toplevel module are know were added to [`/hw/vendor/tagctrl/src/axi_tagctrl_reg_wrap.sv`](/hw/vendor/tagctrl/src/axi_tagctrl_reg_wrap.sv).
| Code Quality  | LINT_SETUP                 | DONE   | Verilator warning waivers are added to [`/hw/top_chip/lint/top_chip_system.vlt`](/hw/top_chip/lint/top_chip_system.vlt#L150) tag controller and the PULP LLC.

[axi_cheri_tagcontroller]: https://github.com/Capabilities-Limited/axi_cheri_tagcontroller
[tag_ctrl_doc]: https://github.com/Capabilities-Limited/axi_cheri_tagcontroller/blob/ea82870f2619bd092d4f7b52ef66513f67fa8e35/docs/tag_controller.adoc
[tag_ctrl_doc_progmod]: https://github.com/Capabilities-Limited/axi_cheri_tagcontroller/blob/ea82870f2619bd092d4f7b52ef66513f67fa8e35/docs/tag_controller.adoc#5-programmers-model--software-interface
