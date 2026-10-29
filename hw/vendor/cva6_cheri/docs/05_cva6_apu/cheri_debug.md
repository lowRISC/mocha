# CHERI debugging support

`COREV_APU` supports CHERI-aware debugging via Sdext (Sdtrig is still a work-in-progress).
To enable this, once the core has been programmed onto the FPGA, you can connect via OpenOCD (using [cva6-rvy-099](https://github.com/Capabilities-Limited/openocd/tree/cva6-rvy-099), which can be built with cheribuild as `./cheribuild.py rvy-openocd`) e.g. as follows:

```
openocd -f corev_apu/fpga/ariane.cfg
```

You can then connect via GDB (using [rvy-099-wip](https://github.com/Capabilities-Limited/cheri-alliance-gdb/tree/rvy-099-wip), which can be built via cheribuild as `./cheribuild.py rvy-gdb`) as follows:

```
gdb <any RVY ELF file> # An ELF file is required to infer the correct arch
target remote :3333
set osabi none
```

The following are examples of GDB commands have been tested and work correctly:

- `Control+C` to halt the processor
- `monitor reset halt` to reset the processor and halt, waiting for further commands
- `si` to single-step the processor
- `c` to resume the processor (restoring all registers unless otherwise modified via GDB)
- `x/10i $pc` to disassemble the next 10 instructions, including RVY disassembly
- `p $pcc` to print the full PCC capability with decoded capability metadata of a paused program
- `info registers` to see all registers, including `ca0` etc. capability aliases
- `b * 0x80000000` to set a breakpoint, though this will be implemented via writing of `ebreak` instructions due to lack of Sdtrig support
