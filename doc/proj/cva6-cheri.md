# CVA6-CHERI

CVA6-CHERI in Mocha is imported from the [lowRISC CVA6-CHERI repo][lowrisc-cva6-cheri], which is in turn forked from the [Capabilities Limited repo][capltd-cva6-cheri].

## Design sign-offs

### D1

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | [The CVA6-CHERI design spec][cva6-cheri-spec] describes the specification for CVA6-CHERI, including links to the parent RISC-V and RISC-V CHERI (Y) specifications.
| Documentation | CSR_DEFINED                | Done   | As the CPU itself, CVA6-CHERI does not have a memory mapped interface for CSRs. The CSRs are defined by the RISC-V specifications listed above and accessed internally within the core.
| RTL           | CLKRST_CONNECTED           | TODO   | This is still in progress. See the [clock audit][clock-audit].
| RTL           | IP_TOP                     | Done   | CVA6-CHERI's top-level `cva6` module is defined in [`cva6.sv`][cva6-top]
| RTL           | IP_INSTANTIABLE            | Done   | CVA6-CHERI's top-level module is instantiated in [`top_chip_system.sv`][cva6-inst-loc].
| RTL           | PHYSICAL_MACROS_DEFINED_80 | TODO   | ...
| RTL           | FUNC_IMPLEMENTED           | Done   | CVA6-CHERI's mainline functionality is implemented. The baseline processor implements the RISC-V specification, and CHERI features are implemented, including manipulating capabilities, enforcing capability checks, and propagating tags and capability metadata throughout the pipeline. This is demonstrating by booting the pure capability CHERI Linux within Mocha, and pure capability CheriBSD in the `COREV_APU` SoC on FGPA.
| RTL           | ASSERT_KNOWN_ADDED         | Done   | These are patched into the vendored [`cva6.sv`][cva6-top]
| Code Quality  | LINT_SETUP                 | Done   | Verilator warning waivers are added to [`top_chip_system.vlt`][waivers].

[capltd-cva6-cheri]: https://github.com/Capabilities-Limited/cheri-cva6
[lowrisc-cva6-cheri]: https://github.com/lowRISC/cva6-cheri
[cva6-inst-loc]: ../../hw/top_chip/rtl/top_chip_system.sv#L381-L404
[cva6-top]: ../../hw/vendor/cva6_cheri/core/cva6.sv
[waivers]: ../../hw/top_chip/lint/top_chip_system.vlt#16
[cva6-cheri-spec]: ../ref/cva6-cheri.md
[clock-audit]: cva6-cheri-d1-clock-audit.md
