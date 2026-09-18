# Debug Module

The Debug Module in Mocha is imported from the [PULP debug module][pulp-debug-repo].
The documentation for the hardware IP block is located [in the vendored HW directory tree][block doc].

## Design sign-offs

### D1

The Debug Module used for D1 sign-off is revision [358f9011][debug-hash], the same as used in OpenTitan.
The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].

The only planned changes to the debug module after D1 are modest changes in the debug ROM and debug memory to enable capability-aware debugging.

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | [Debug Module specification][block doc].
| Documentation | CSR_DEFINED                | TODO   | The DMI registers are defined here: [DMI registers][dmi-registers]. The memory-mapped registers from the core are defined here: [Debug Memory Map][bus-registers]. TODO: two additional registers are required for CHERI, to indicate the program buffer is in integral pointer mode or capability pointer mode. These are currently allocated offsets 0x120 and 0x128.
| RTL           | CLKRST_CONNECTED           | Done   | `dm_top.sv` correctly connects `clk_i` and `rst_ni` to `dm_csrs.sv`, `dm_sba.sv`, and `dm_mem.sv`. `dm_csrs.sv` instantiates a `prim_fifo_sync` that connects up the right clock, but changes reset domain to `dmi_rst_ni`, with a comment confirming this is intended. `dm_mem.sv` and `dm_sba.sv` have no further submodules.
| RTL           | IP_TOP                     | Done   | This module is defined in `dm_top.sv`.
| RTL           | IP_INSTANTIABLE            | Done   | It is instantiated in top chip system.
| RTL           | PHYSICAL_MACROS_DEFINED_80 | TODO   | ...
| RTL           | FUNC_IMPLEMENTED           | Done   | Debug functionality is already impelemented and smoke tested within Mocha. Small changes are expected to support capability debugging.
| RTL           | ASSERT_KNOWN_ADDED         | TODO   | ...
| Code Quality  | LINT_SETUP                 | TODO   | ...


[block doc]: ../../hw/vendor/pulp_riscv_dbg/doc/debug-system.md
[pulp-debug-repo]: https://github.com/pulp-platform/riscv-dbg
[debug-hash]: https://github.com/pulp-platform/riscv-dbg/tree/358f9011
[dmi-registers]: ../../hw/vendor/pulp_riscv_dbg/doc/debug-system.md#debug-module-registers
[bus-registers]: ../../hw/vendor/pulp_riscv_dbg/doc/debug-system.md#debug-memory-map
