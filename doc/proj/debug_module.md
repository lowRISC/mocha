# Debug Module

The Debug Module in Mocha is imported from the [PULP debug module][pulp-debug-repo].
The documentation for the hardware IP block is located [in the vendored HW directory tree][block doc].

## Design sign-offs

### D1

The Debug Module used for D1 sign-off is revision [358f9011][debug-hash], the same as used in OpenTitan.
The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].

This D1 signoff is for the non-CHERI version of the debug module currently instantiated in Mocha.
The only planned changes to the debug module after D1 are modest changes in the debug ROM and debug memory to enable capability-aware debugging.

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | [Debug Module specification][block doc].
| Documentation | CSR_DEFINED                | Done   | The DMI registers are defined here: [DMI registers][dmi-registers]. The memory-mapped registers from the core are defined here: [Debug Memory Map][bus-registers].
| RTL           | CLKRST_CONNECTED           | Done   | `dm_top.sv` correctly connects `clk_i` and `rst_ni` to `dm_csrs.sv`, `dm_sba.sv`, and `dm_mem.sv`. `dm_csrs.sv` instantiates a `prim_fifo_sync` that connects up the right clock, but changes reset domain to `dmi_rst_ni`, with a comment confirming this is intended. `dm_mem.sv` and `dm_sba.sv` have no further submodules.
| RTL           | IP_TOP                     | Done   | This module is defined in `dm_top.sv`.
| RTL           | IP_INSTANTIABLE            | Done   | It is instantiated in top chip system.
| RTL           | PHYSICAL_MACROS_DEFINED_80 | Done   | The debug module includes a dynamically generated [Debug ROM][debug-rom]. This is currently 160 bytes.
| RTL           | FUNC_IMPLEMENTED           | Done   | Debug functionality is already implemented and smoke tested within Mocha. Small changes are expected to support capability debugging.
| RTL           | ASSERT_KNOWN_ADDED         | Done   | These are patched into the vendored `dm_top.sv`
| Code Quality  | LINT_SETUP                 | Done   | Verilator linting is performed as part of the Mocha build. Waivers are specified in [pulp_riscv_dbg.vlt][debug-waivers].


[block doc]: ../../hw/vendor/pulp_riscv_dbg/doc/debug-system.md
[pulp-debug-repo]: https://github.com/pulp-platform/riscv-dbg
[debug-hash]: https://github.com/pulp-platform/riscv-dbg/tree/358f9011
[dmi-registers]: ../../hw/vendor/pulp_riscv_dbg/doc/debug-system.md#debug-module-registers
[bus-registers]: ../../hw/vendor/pulp_riscv_dbg/doc/debug-system.md#debug-memory-map
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[debug-rom]: ../../hw/vendor/pulp_riscv_dbg/debug_rom/debug_rom.sv
[debug-waivers]: ../../hw/vendor/lint/pulp_riscv_dbg.vlt
