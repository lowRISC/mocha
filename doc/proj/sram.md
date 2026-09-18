# SRAM

The SRAM is specified in the [SRAM specification][block doc] and implemented in `axi_sram.sv`.
The block converts AXI4 requests from the main crossbar into accesses on two `prim_ram_1p` instances: a data RAM and a separate tag RAM holding one CHERI tag bit per 128-bit aligned region, communicated over `wuser` and `ruser`.
It is sized for Mocha in [top_chip_system.sv][instantiation]: 128 KiB of data, so a 14-bit word address.

The rest of this document contains the design checklist for the SRAM hardware IP block for the CHERI Mocha top.
For more details on the stages and the current state for each block, please refer to the [stages documentation][stages].

## Design sign-offs

### D1

The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].
This sign-off is based on commit [`e9a63ad`][d1-commit].

| Type          | Item                       | Status      | Note/Collaterals |
|---------------|----------------------------|-------------|------------------|
| Documentation | SPEC_COMPLETED             | Done        | [SRAM specification][block doc] in the architecture document.
| Documentation | CSR_DEFINED                | Done        | The block has no registers; it is addressed as memory over AXI4.
| RTL           | CLKRST_CONNECTED           | Done        | Modules containing submodules checked: `axi_sram.sv`, `axi_to_detailed_mem.sv`, which also declares `mem_stream_to_banks_detailed`, `stream_fork_dynamic.sv`, `fifo_v3.sv`, `prim_fifo_sync.sv`, `prim_fifo_sync_cnt.sv` and `prim_count.sv`. The remaining submodules are leaves: `stream_fork`, `prim_flop` and `prim_ram_1p` take a clock and reset, and `stream_join`, `stream_join_dynamic` and `stream_mux` are confirmed to be purely combinational.
| RTL           | IP_TOP                     | Done        | This module is defined in `axi_sram.sv`. It has its own [fusesoc core][fusesoc file] file and it is compiled as part of `top_chip_system.core`.
| RTL           | IP_INSTANTIABLE            | Done        | It is instantiated in top chip system.
| RTL           | PHYSICAL_MACROS_DEFINED_80 | Waived      | The data RAM is fixed at 16384 words of 64 bits and the tag RAM at 128 words of 64 bits, one tag bit per capability slot. Both instances tie `cfg_i` to zero and leave `cfg_rsp_o` open; [issue #715][ram cfg] will bring the RAM configuration out to the block boundary as inputs and outputs. The RAM primitive itself is the subject of [issue #694][ram prim].
| RTL           | FUNC_IMPLEMENTED           | Done        | Aligned reads, writes, bursts and tag storage are implemented. Atomic requests are currently treated as regular requests; the RTL will be updated to return an AXI subordinate error as per [issue #695][atomics].
| RTL           | ASSERT_KNOWN_ADDED         | Done        | Output assertions are [here][output asserts] and cover the AXI response handshakes, the B channel and the R channel control fields. The read data and the tag data do not have assertions; memory that has never been written reads back as undefined, so tracking which locations are initialised is a DV task rather than an RTL one.
| Code Quality  | LINT_SETUP                 | Done        | `axi_sram.core` and `top_chip_system.core` each have a Verilator `lint` target with `-Wall`; the block produces no warnings in its own RTL and none are waived in [top_chip_system.vlt][lint waivers].

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

[block doc]: ../ref/arch.md#sram-specification
[stages]: stages.md
[design stages]: stages.md#design-stages
[verification stages]: stages.md#verification-stages
[ram cfg]: https://github.com/lowRISC/mocha/issues/715
[ram prim]: https://github.com/lowRISC/mocha/issues/694
[atomics]: https://github.com/lowRISC/mocha/issues/695
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[d1-commit]: https://github.com/lowRISC/mocha/commit/e9a63add98f273bf0148c27f5f16c219fbc5aaa1
[instantiation]: ../../hw/top_chip/rtl/top_chip_system.sv
[output asserts]: ../../hw/top_chip/rtl/axi_sram.sv#L174-L183
[lint waivers]: ../../hw/top_chip/lint/top_chip_system.vlt
[fusesoc file]: ../../hw/top_chip/axi_sram.core
