# CHERI Mocha

The CHERI Mocha project is a reference design for an integrated SoC subsystem for secure enclaves that use CHERI.
Secure enclaves are usually part of a larger SoC and are tasked with security critical tasks like user authentication, password storage, etc.
Resolving memory safety issues is paramount in the security-critical use cases that need to run on secure enclave systems.
This is why we designed CHERI into Mocha to deterministically guarantee spatial and temporal memory safety.
CHERI Mocha is a reference design for ASICs that demonstrates how a CHERI-enabled core, bus and memories can be instantiated in a subsystem SoC with commercial-grade verification.

If you want to try out using Mocha, we currently support the [Genesys 2 FPGA board][] and simulation using Verilator or Xcelium.
For more details head to our [release page](https://github.com/lowRISC/mocha/releases) and [development guide](doc/ref/dev_guide.md).

CHERI Mocha is part of the [COSMIC project](https://cosmic-project.lowrisc.org/), which is a collaboration between lowRISC, Capabilities Limited and Oxford University Innovation.
It is work that is funded by Innovate UK and the Department for Science, Innovation and Technology (grant number 10168492).

## Architecture

The block diagram of the Mocha SoC is depicted below.
We are re-using numerous [OpenTitan](https://opentitan.org/) blocks since they are open-source and commercial grade.
Mocha includes an application class processor to support operating systems that need a memory management unit (MMU).
This is because enclave systems usually run operating systems that need virtual memory, like those based on L4, as opposed to real-time operating systems.
For more detailed discussion on the architecture including clock domains and memory map, please look at the [architecture documentation](doc/ref/arch.md).

![Mocha block diagram](doc/img/mocha_architecture_paths_only.svg)

## Release timeline

As we launch this project, we expect the following release schedule:

| Release | Date | Details |
|--|--|--|
| 0.0.1 (MVP-1) | March 2026 | *Available now.* First minimal viable product (MVP-1) which includes essential IP blocks and access to SRAM as well as DRAM. It supports baremetal testing in both CHERI and integer modes. |
| 0.1.0 (MVP-2) | June 2026 | Second minimal viable product (MVP-2) with all blocks integrated, as well as support for booting CHERI-Linux. |
| RC-1 | Dec 2026 | First release candidate (RC-1) including initial design and verification sign-offs. |

## Verification

There is a dashboard of the nightly verification runs for Mocha, which can be found [here](https://cosmic-project.lowrisc.org/dashboard/index.html).
It shows test pass rates and coverage metrics for all the blocks currently integrated.
Initially this dashboard is expected to grow as we add more blocks and the red statuses will turn to green as we integrate more of our verification effort.
For more information on our top-level verification framework, check out its [dedicated documentation](hw/top_chip/dv/README.md).
The current sign-off status for each block can be found in the [design stages documentation](doc/proj/stages.md).

## Contributing

Feel free to open issues if you have any questions or would like to contribute.
We recommend opening an issue to discuss a contribution before preparing a pull request.

## License

Unless otherwise noted, everything in this repository is covered by the Apache License, Version 2.0 (see [LICENSES/Apache-2.0.txt](https://github.com/lowRISC/mocha/blob/main/LICENSES/Apache-2.0.txt) for full text).

[Genesys 2 FPGA board]: https://digilent.com/shop/genesys-2-amd-kintex-7-fpga-development-board
