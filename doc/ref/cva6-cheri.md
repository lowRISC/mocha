# CVA6-CHERI design specification

CVA6-CHERI is a dual-issue superscalar in-order 64-bit RISC-V core with support for sufficient ISA extensions as to be "Linux Capable".
It is based on the [CVA6][cva6-upstream] core maintained by the OpenHW Foundation.
It is augmented with CHERI "RVY" extensions to enable memory safety and compartmentalisation enforcement as the Mocha enclave processor.

As a RISC-V core, CVA6 itself is designed to comply with the [RISC-V ISA specification][riscv-spec].
Design documents for CVA6's microarchitecture are present in the [repo's `docs` subdirectory][cva6-cheri-docs].

The [riscv-cheri specification][rvy-spec] describes the operation of the CHERI instructions.
The CVA6-CHERI IP vendored into Mocha targets version [0.9.3][rvy-spec-093] of this specification.

## ISA Extension Configuration
The following extensions should be supported, with full capability support where applicable:
* F (floating point)
* D (double-precision floating point)
* C (compressed instructions)
* A (atomics)
* Y (CHERI: both purecap and hybrid)
* Zkn (scalar cryptography)
* B (bit manipulation)
* Zicond (branchless conditional instructions)
* Sdext (debug support)
* Sdtrig (debug trigger support)
* Zicbom (cache management operations)

## Microarchitecture
A CHERI processor requires new features; this section lists how these features are achieved at a high level.

### Capability datatype support
RVY extends integer x registers architecturally to 128 bit (plus one bit tag) registers on RV64.
This is implemented as two different types in CVA6-CHERI:
 - `cap_mem_t`: 129 bits
 - `cap_reg_t`: "expanded" type that partially decompresses some of the fields
These type definitions and utility functions to manipulate them can be found in [`cva6_cheri_pkg`][cva6-cheri-pkg].
They are also used as bit-vectors of the appropriate width (CLEN+1, and REGLEN respectively) throughout the pipeline.
The capabilities are expanded into the `cap_reg_t` on the path in from memory, meaning all registers within the core and forwarding paths use the `cap_reg_t` type.

### Tagged memory support
RVY defines an additional bit of state for each 128-bit (16-byte) word of memory.
This bit is preserved for 128-bit loads/stores into/from registers, and is cleared in memory words on any other width of store.
In CVA6-CHERI, tags are stored alongside the data throughout the core and caches.
On the output of the L1 DCache, the tags are communicated on the user bits of the AXI R and W channels.
This can be connected to the `axi_cheri_tagcontroller` module, which converts an AXI bus with CHERI tags in the user bits by splitting the tags and storing them in a backing region of DRAM.
This allows the tags to be supported without any additional changes to the SoC or DRAM behind the tag controller.

### Memory access checks
All memory accesses in an RVY core must be checked against the bounds of a capability.
Even in Integral Pointer Mode mode, where standard RV64 programs execute unchanged, memory accesses are checked against the bounds of the Default Data Capability (DDC) CSR.
In Capability Pointer Mode, memory accesses are checked against bounds in the address operand register.
These checks can be found in the [load-store unit][lsu].

### Capability manipulation operations
RVY specifies new ALU instructions that receive capability operands and produce capability results.
Some of these must perform new floating-point-like operations to decode or encode compressed bounds.
These are implemented in [`cva6_cheri_pkg`][cva6-cheri-pkg]

### Program counter capability (PCC)
RVY specifies bounds for the program counter, extending it to the Program Counter Capability, PCC.
An RVY implementation must check that the PC address is within the bounds of PCC before executing, must store the full PCC into the link register on a jump-and-link instruction, and must record and restore the full PCC to and from CSRs on exceptions.
In CVA6-CHERI, the front-end fetches based purely on predicted addresses.
These are then checked against the PCC before the instruction is issued.
The [`issue_read_operands`][iro] module handles most of the PCC management.
There is only a single PCC present in the pipeline at a time, with `issue_read_operands` applying back-pressure on an attempted change until all prior instructions have retired.

### Control and Status Registers (CSRs)
All CSRs that can be used to hold addresses are extended to hold full, 129-bit capabilities in RVY.
This includes both registers primarily interpreted as addresses, such as (m/s)epc and (m/s)tvec, and registers that are general purpose, such as (m/s)scratch and dscratch0.
The changes to CSRs are mostly found in the [`csr_regfile`][csr-regfile].

[riscv-spec]: https://github.com/riscv/riscv-isa-manual
[cva6-upstream]: https://github.com/openhwfoundation/cva6
[cva6-cheri-docs]: ../../hw/vendor/cva6_cheri/docs
[rvy-spec]: https://github.com/riscv/riscv-cheri
[rvy-spec-093]: https://github.com/riscv/riscv-cheri/releases/tag/v0.9.3-prerelease
[cva6-cheri-pkg]: ../../hw/vendor/cva6_cheri/core/include/cva6_cheri_pkg.sv
[lsu]: ../../hw/vendor/cva6_cheri/core/load_store_unit.sv
[iro]: ../../hw/vendor/cva6_cheri/core/issue_read_operands.sv
[csr-regfile]: ../../hw/vendor/cva6_cheri/core/csr_regfile.sv
