# CHERI (RVY Extension) Implementation
CVA6-CHERI is a fork of CVA6 that has been modified with support for version 0.9.9 of the RVY CHERI RISC-V architecture specification.
This documentation gives information of changes made to the microarchitecture for CVA6-CHERI.
The upstream CVA6 documentation should be used for information about non-CHERI features.
See the Issue tracker for information on any parts of the specification not yet implemented and plans to update to future versions.

## ISA Extension Configuration
The main tested configuration of CVA6-CHERI is `core/include/cv64a6_imafdczcheri_sv39_hpdcache_wb_config_pkg.sv`.
This configuration is regularly tested both in simulation with random instruction sequence generators and on FPGA running test suites on the CHERI Linux and CheriBSD operating systems.
Currently, we only support RV64 CHERI configurations.
Many other configurations build and are expected to work correctly, but are very sparsely tested by Capabilities Limited.
The following extensions are enabled, with full capability support where applicable:
- F (floating point)
- D (double-precision floating point)
- C (compressed instructions)
- A (atomics)
- Y (capability instructions; this is a new configuration option not present in upstream CVA6)
- ZYhybrid (hybrid capability instructions; this is a new configuration option not present in upstream CVA6)
- Zkn (scalar cryptography)
- Sdext (debug support)

The following are enabled, but have not yet been modified with capability support:
- B (bit manipulation)
- Zicond (branchless conditional instructions)
The following are disabled, and will not work on CVA6-CHERI currently:
- H (hypervisor)
- V (vector)
- Zicbom (cache management operations)
- Sdtrig (debug trigger support)

The issue tracker lists plans to enable more extensions.

## Microarchitectural Configuration
CVA6-CHERI introduces one new microarchitectural option to the configuration files.

CheriCapTagWidth - This value must be `int'(1)`

## Microarchitecture
A CHERI processor requires new features; this section lists how these features are achieved at a high level.
Block-level descriptions of detailed descriptions of CHERI modifications follow.

### Capability datatype support
RVY extends integer x registers architecturally to 128 bit (plus one bit tag) registers on RV64.
This is implemented as two different types in CVA6-CHERI:
 - `cap_mem_t`: 129 bits
 - `cap_reg_t`: "expanded" type that partially decompresses some of the fields

These type definitions and utility functions to manipulate them can be found in `core/include/cva6_cheri_pkg.sv`.
They are also used as bitvectors of the appropriate width (`CLEN+1`, and `REGLEN` respectively) throughout the pipeline.
The capabilities are expanded into the `cap_reg_t` on the path in from memory, meaning all registers within the core and forwarding paths use the `cap_reg_t` type.

### Tagged memory support
RVY defines an additional bit of state for each 128-bit (16-byte) word of memory.
This bit is preserved for 128-bit loads/stores into/from registers, and is cleared in memory words on any other width of store.
While tagged memory can be implemented directly, e.g. with ECC or SRAM with 129-bit words, it is common to emulate tagged memory using a tag controller backed by a table in DRAM.
In CVA6-CHERI, tags are stored alongside the data throughout the core and caches.
On the output of the L1 DCache, the tags are communicated on the user bits of the AXI R and W channels.
The `axi_cheri_tagcontroller` module then converts an AXI bus with CHERI tags in the user bits by splitting the tags and storing them in a backing region of DRAM.
For performance, it also caches the tags.
This allows the tags to be supported without any additional changes to the SoC or DRAM behind the tag controller.

### Memory access checks
All memory accesses in an RVY core must be checked against the bounds of a capability.
Even in Zyhybrid mode, where standard RV64 programs execute unchanged, memory accesses are checked against the bounds of the Default Data Capability (DDC).
In pure capability mode, memory accesses are checked against bounds in the address operand register.
These checks can be found in the `core/load_store_unit.sv`

### Capability manipulation operations
RVY specifies new ALU instructions that receive capability operands and produce capability results.
Some of these must perform new floating-point-like operations to decode or encode compressed bounds.

### Program counter capability (PCC)
RVY specifies bounds for the program counter, extending it to the Program Counter Capability, PCC.
An RVY implementation must check that the PC address is within the bounds of PCC before executing, must store the full PCC into the link register on a jump-and-link instruction, and must record and restore the full PCC to and from CSRs on exceptions.
In CVA6-CHERI, the frontend of the fetches based purely on predicted addresses.
These are then checked against the PCC before the instruction is issued.
The `core/issue_read_operands.sv` module handles most of the PCC management.
There is only a single PCC present in the pipeline at a time, with `issue_read_operands` applying backpressure on an attempted change until all prior instructions have retired.

### Control and Status Registers (CSRs)
All CSRs that can be used to hold addresses are extended to hold full, 129-bit capabilities in RVY.
This includes both registers primarily interpreted as addresses, such as `(m/s)epc` and `(m/s)tvec`, and registers that are general purpose, such as `(m/s)scratch` and `dscratch0`.
The changes to CSRs are mostly found in `core/csr_regfile.sv`.

## CVA6-CHERI Modifications Organised by Module
This section lists CVA6-CHERI changes relative to upstream CVA6 organised by pipeline stage and module.
Modules that are not listed generally have no changes or very few changes.
Changes to support the RVFI\_DII verification interface are not included here, though they do appear in a diff between upstream and the RVY branch.

### Instruction Decode
The Instruction Decode stage (`id_stage.sv`) in CVA6-CHERI diverges from upstream CVA6 primarily to support tracking `int_mode`.
RVY defines two modes for decoding instructions:
- integer mode, similar to RV64I with additional capability instructions
- pure capability mode, which repurposes common memory operations to expect full capability operands

While the mode bit is architecturally part of PCC, programs that switch mode will usually use `ymodeswi/y` instructions which switch to a fixed mode.
As a result, the current mode can be kept in sync by inspecting the instruction stream in the decode stage.
The decode stage module implements a system for tracking the current mode, even across changes within a dual-issue bundle.
This also requires fix-ups on redirection of PCC, which required new signals into this stage which previously only went to the fetch stage, which previously exclusively owned the PC.

### Decoder
The Decoder module (`decoder.sv`) in CVA6-CHERI has been extended with sensitivity to the `int_mode` bit and with support for RV64Y instructions.
RV64I instructions that use addresses are sensitive to the `int_mode` bit, which is tracked in the parent decode module, and must choose between checking against DDC or the bounds of their operand.
All new RVY instructions are added under the `OpcodeRVY` case in the decoder.
In addition, the decoder has support for a new immediate format, `SCIMM`, used for the `YBNDSWI` instruction.

### Compressed Decoder
The Compressed Decoder module (`compressed_decoder.sv`) is extended with sensitivity to the `int_mode` bit, allowing several pointer-related instructions to be used for capability-explicit variants when in pure capability mode.

### Issue Stage
The CVA6 issue stage contains the register file, scoreboard with all record keeping for outstanding instructions, and the issue/dispatch logic.
CVA6-CHERI updates to this stage include widening all operands to `REGLEN` to allow capability-wide registers, and PCC bounds tracking.

### Scoreboard
Besides support for `REGLEN` operands, the primary change to the scoreboard for CVA6-CHERI is to support reporting a PCC bounds exception from the Issue Stage, and also reporting when the backend is full to facilitate releasing the Issue Stage when a PCC bounds change has been encountered.

### Issue Read Operands
The Issue Read Operands module contains new functionality to track the current value of PCC bounds.
CVA6 tracked the PC in instruction fetch, reading it to issue instruction memory requests, and updating it speculatively from the BTB, and redirecting from the branch unit and commit as required.
For CVA6-CHERI, the bounds of PCC do not need to be read except when writing PCC to a register in Execute, reporting its value in EPC on Commit, and for bounds checking.
In addition, the bounds of PCC are typically held constant for all instructions in a compile block.
Therefore, CVA6-CHERI allows all instructions in the backend of the pipeline (between Issue and Commit) to share a single value of PCC, only tracking a differing address field for each.
This single PCC value is stored in the Issue Read Operands module.
The Issue Read Operands module has been extended to not only store and export the current value of PCC, but also to receive reports from the branch unit that an instruction will change the value of PCC bounds or permissions and manage control flow around these changes so that instructions with the new PCC are not issued until all instructions belonging to the old PCC have committed.
In addition, all PC redirect paths are also plumbed into this module to allow updating PCC bounds on branch mispredict or exception.
Note that while only the PCC bounds and permissions are notionally stored here, a full PCC value is required, as the full bounds cannot be reconstituted without a representative address, as the bounds are compressed relative to an address in the range.
Issue Read Operands also includes logic to check the bounds of each instruction address against PCC, as well as PCC permissions.
Issue Read Operands is also responsible for issuing instructions to the new Capability Logic Unit (CLU) on the correct port.
The CLU and the branch unit (`ctrl_flow`) share a port in Execute, as Capability Jump operations require both functionalities.
Correct scheduling conflicts are implemented in this module.

### Execute Stage
CVA6-CHERI primarily modifies the execute stage (`ex_stage.sv`) of CVA6 by extending operands to `REGLEN` from `XLEN`, and by adding the Capability Logic Unit (CLU).
When built with RVY (`CVA6Cfg.CheriPresent`), operands and results are >128-bit values that hold partially decoded capabilities, but which hold any 64-bit integer values in the lower 64-bits.
Therefore, paths generally pass full `REGLEN` values to any unit that needs to manipulate full capabilities, or `reg_to_x` or `x_to_reg` to convert to `XLEN` values for pure integer units.
The execute stage also instantiates the new CLU and feeds operands to it and the result from it.

### Cheri Unit (CLU)
The Cheri Unit, also called the Capability Logic Unit (CLU) in the code base, is a new module for CVA6-CHERI which implements Execute stage ALU-style operations for CHERI instructions.
The CLU has a similar interface to the ALU and FPU, but all operands and results are `REGLEN`-sized.
This module relies heavily on the `cva6_cheri_pkg` to implement functions that extract fields (e.g. `get_cap_reg_base`) and perform capability transformations (e.g. `set_cap_reg_bounds`).
The CLU does not throw exceptions, but can reflect capability policy violations by clearing the tag of the resulting capability.

### ALU
The CVA6-CHERI arithmetic logic unit (ALU) has very few changes relative to upstream CVA6 beyond casting 129-bit register values to 64-bit operands for integer arithmetic operations.

### Branch Unit
CVA6-CHERI implements capability jumps and links, that is, jumps and links that write and read PCC bounds from and to capability-width general-purpose registers.
The branch unit supports not only JALR operations, which set a 64-bit address within the existing PCC bounds, but a new CJALR operation that receives new bounds with the address operand.
The CJALR operation also links a sealed version of the `next_pc` capability, though both JALR and CJALR share the same code path here, but JALR is decoded to only a zero-extended 64-bit value, as with many non-capability risc-v instructions, and will thus drop the bounds when writing the destination register value.
Importantly, the branch unit will also compare the bounds of the target PCC against the bounds of the PCC that fetched the jump instruction, and report whether the bounds have changed.
This allows separate prediction of PCC bounds and PC address.
The current implementation pauses issue when PCC bounds change until the CJALR that changed bounds commits.
This allows the implementation to assume that all instructions in the back end share the same PCC bounds, broadcasting a single value of PCC bounds from the issue unit.

### Load Store Unit (LSU)
The CVA6-CHERI Load Store Unit (LSU) has been modified over the baseline CVA6 to implement all bounds and permissions checks for capability memory operations, and also to support capability-wide memory operations.
The LSU decodes the top and base the authorising capability of every data memory operation, and checks that the lowest address of the memory operation is equal to or above the base and that the highest address is below the top.
The LSU also checks a large number of permissions and levels rules for memory access.
The LSU also passes metadata into the MMU to perform PTE capability permissions, including generation checks.
The LSU has also been modified to support 128-bit loads and stores in addition to all other memory operation sizes.
These include not only standard loads and stores, but also the `AMO_LRY`, `AMO_SCY`, and `AMO_SWAPY` instructions.

### Load Unit
Similarly to the Load Store Unit, the primary additions to the load unit for CVA6-CHERI are to track metadata to check new RVY exceptions.
There are also some changes to support wider, 128-bit memory operations.

### Store Unit
Similarly to the Load Store Unit, the store unit for CVA6-CHERI has changes to support 128-bit operations, atomic operations, and RVY exception checks.

### Store Buffer
The CVA6-CHERI store buffer modifies the CVA6 store buffer to support a larger 128-bit word size, and also to track the capability tag for each entry.

### Memory Management Unit (MMU)
The MMU in CVA6-CHERI has changes to support new PTE bits required by RVY, as well as checks for those new bits.

### Page Table Walker (PTW)
The Page Table Walker in CVA6-CHERI has changes to support new CHERI exceptions and also to support a native 128-bit memory interface.

### Commit Stage
The Commit Stage of CVA6-CHERI handles new RVY exceptions and imports PCC bounds, as well as extending many signals from `XLEN` to `REGLEN`.
The full PCC of the committing instruction requires the PC address for the instruction, which comes into the commit stage from the scoreboard, but requires the current PCC bounds from the Issue Read Operands module in order to reconstitute the full PCC for this instruction that should be recorded on exception.
As this full PCC is not used in this module, but is exported to the CSR register file, we will likely remove these signals from the Commit Stage in the future.

