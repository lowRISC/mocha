# Architecture

The Mocha architecture contains two crossbars.<!-- ibyb3i_x -->
One crossbar is 64-bit width and is meant for the main memory.<!-- iiu1i5_x -->
The other crossbar is uncached and meant to contain the peripherals.<!-- e16ysv_x -->
Because most of these peripherals are imported from OpenTitan, in the first instance this bus is implemented as a TileLink Ultra-Lightweight bus with 32-bit width.<!-- ch8b58_x -->

![Mocha block diagram](../img/mocha.svg)<!-- m00a78_x -->

## Clock domains

There are three clock domains in Mocha.<!-- rfj4pd_x -->

1. Main: The main clock domain is the high-speed clock domain that runs the CVA6 core as well as the AXI crossbar it connects to, the AXI tag controller, debug module and the SRAM.<!-- yj8kx5_x -->
2. IO: The IO clock drives most of the peripherals and runs at a lower speed than the main clock.<!-- xe90jz_x -->
   It drives the TileLink bus and most of the peripherals that are connected to it like the UART and the SPI device.<!-- 4vkzbx_x -->
3. AON: The always on clock is also a low-speed clock with the difference being that it is always on.<!-- s61dxh_x -->
   Both the main and IO clocks can be disabled and are turned off when a system reset is requested.<!-- 68url6_x -->
   The always on clock drives the clock, reset and power managers and allows the system to come out of reset.<!-- w5ylk6_x -->

## Memory map

This is the current memory map for Mocha, where the base and top addresses are inclusive, and reserved is the amount of memory reserved for this function:<!-- mcbp27_x -->

![Mocha memory map](../img/memmap.svg)<!-- bxskuw_x -->

## Top-level interface

The Mocha top will need a few top-level inputs.<!-- i7mqt7_x -->
Some of these are listed here:<!-- 1cwb13_x -->
- Clock outputs from PLLs.<!-- p4bt5a_x -->
- Rollback counter backed by OTP.<!-- 7215fb_x -->
- Debug and design for test enable pins.<!-- 5fh61t_x -->
- True random noise source to drive the entropy source.<!-- 8u3w8m_x -->
- AXI subordinate port to connect to the mailbox.<!-- fna4to_x -->

In terms of output, the top-level will need output signals:<!-- tvdygx_x -->
- Key to provide an AES engine outside of the secure enclave with the memory encryption key.<!-- fv7l7k_x -->
- AXI manager port to interact with the rest of the chip.<!-- du1glx_x -->

## SRAM specification

The static random-access memory (SRAM) in CHERI Mocha is mainly used as the stack and heap for the boot firmware that lives in the read-only memory (ROM).<!-- 21k32t_x -->
However, it should also be possible to execute from SRAM.<!-- lhjkel -->
Once code starts executing from dynamic random-access memory (DRAM), we don't envision using SRAM anymore.<!-- a3l94p_x -->

The SRAM block has four ports:<!-- qohtih -->
- Clock input<!-- 947rwh -->
- Reset input<!-- rrni5j -->
- AXI4 request input from the main SoC sub-system crossbar<!-- pgo845 -->
- AXI4 response output back to the main crossbar<!-- n5txiq -->

Inside the block it translates the AXI4 requests into an SRAM interface that our primitive RAM wrappers use.<!-- vknoin -->
It needs to support AXI4 protocol including:<!-- mcykq8 -->
- Bursts, where the last signal must be indicated correctly.<!-- o02amt -->
- Response must have the same AXI4 ID as the request<!-- 4t4cew -->
- Atomic support is *excluded*.<!-- bsi4rc -->
- The data width is 64 bits.<!-- jeluga -->
- The address range and size of the SRAM are defined in the [memory map](#memory-map). Accesses outside this range must return an error, including if only part of the burst is outside the memory range.<!-- u0s8nt -->
- Responses must return within a bounded amount of time that may be proportional to the length of the burst.<!-- 34ld5i -->
- Only aligned 64-bit accesses are allowed.<!-- lfcb7q -->

There needs to be 1 CHERI tag bit per 128-bit aligned region.<!-- 01skcc -->
A tag should only be set to 1 by writing a full 128-bit aligned region.<!-- 8rlwol -->
This 128-bit aligned transaction must be part of a single burst.<!-- 35vdeg -->
The CHERI tag bits are communicated through a single user bit per AXI4 flit (`wuser` and `ruser` for writes and reads respectively).<!-- u95b14 -->
There should be an assertion to notify when writes occur where `wuser` is set to 1 which is not part of a full capability write.<!-- bj8we7 -->
There should also be an assertion for `wuser` mismatches, where one part of the capability is marked as valid while another is invalid in the same transaction.<!-- 9a3xf6 -->
If a portion of the 128-bit aligned region is written it must clear the tag for the whole region including when a partial write strobe is used.<!-- 893tz4 -->

Reads that only read part of a 64-bit value are allowed from valid capability regions, but these should have their tag cleared.<!-- raa5pw -->
Burst reads from the SRAM must have the appropriate CHERI tags set for each address, so a valid capability must have the user bits set for both of the 64-bit flits it is being sent back, and a mixture of capability and non-capability data is allowed in a burst.<!-- kn6exz -->
The SRAM is allowed to mark a capability as invalid by setting one or both of the `ruser` bits to zero, so the core must AND the two `ruser` values together to determine the validity of a capability.<!-- af8sx6 -->
Tags should be stored in a separate block of memory from the data, this is to allow future optimisations where bulk-reads of tags are desired.<!-- lzoy40 -->

The initial value of the SRAM including the tags is undefined at start-up.<!-- hqbiau -->
