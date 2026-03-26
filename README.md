# CHERI Mocha

The CHERI Mocha project is a reference design for an integrated SoC subsystem for secure enclaves that use CHERI.
Secure enclaves are usually part of a larger SoC and are tasked with security critical tasks like user authentication, password storage, etc.
These enclave systems often include application class processors because they need to support an MMU-enabled operating system, usually based on L4 or something clean slate, as opposed to real-time operating systems.
CHERI is an important technology to evaluate in these systems because of the high-level of confidentiality, integrity and availability that is required here.
This open-source design is meant to be a reference for ASICs with any proprietary primitives clearly stubbed out and isolated.
Specifically, any hardware that requires changes with respect to CHERI should be in the open source since this is critical to providing a production-grade CHERI-enabled subsystem that can be integrated into an ASIC.

If you want to try out using Mocha, we currently support the [Genesys 2 FPGA board][] and simulation using Verilator or Xcelium.

CHERI Mocha is part of the [COSMIC project](https://cosmic-project.lowrisc.org/), which is a collaboration between lowRISC, Capabilities Limited and Oxford University Innovation.
It is work that is funded by Innovate UK and the Department for Science, Innovation and Technology (grant number 10168492).

## Architecture

The planned block diagram of the Mocha SoC is depicted below.
We are re-using a lot of [OpenTitan](https://opentitan.org/) blocks since they are open-source and commercial grade.
For more detailed discussion on the architecture including clock domains and memory map, please look at the [architecture documentation](doc/ref/arch.md).

![Mocha block diagram](doc/img/2026-03-26c_Mocha_PATHS_ONLY.svg)

## Release timeline

As we launch this project, we expect the following release schedule:

| Release | Date | Details |
|--|--|--|
| 0.0.1 (MVP-1) | March 2026 | *Available now.* First minimal viable product (MVP-1) which includes essential IP blocks and access to SRAM as well as DRAM. It supports baremetal testing in both CHERI and integer modes. |
| 0.0.2 (MVP-2) | June 2026 | Second minimal viable product (MVP-2) with all blocks integrated, as well as support for CHERI-Linux or CheriBSD. |
| 0.1.0 (RC-1) | Dec 2026 | First release candidate (RC-1) including initial design and verification sign-offs. |

## Quick start

Please follow the [quick start guide](doc/ref/dev_guide.md#quick-start-from-release) to see how to run simulations and program your FPGA based on our latest release.
To use our FPGA build you will need to order a [Genesys 2 FPGA board][].

## Verification

There is a dashboard of the nightly verification runs for Mocha, which can be found [here](https://cosmic-project.lowrisc.org/reports).
It shows test pass rates and coverage metrics for all the blocks currently integrated.
Initially this dashboard is expected to grow as we add more blocks and the red statuses will turn to green as we integrate more of our verification effort.
For more information on our top-level verification framework, check out its [dedicated documentation](hw/top_chip/dv/README.md).

## Contributing

Feel free to open issues if you have any questions or would like to contribute.
We recommend opening an issue to discuss a contribution before preparing a pull request.

## License

Unless otherwise noted, everything in this repository is covered by the Apache License, Version 2.0 (see [LICENSES/Apache-2.0.txt](https://github.com/lowRISC/mocha/blob/main/LICENSES/Apache-2.0.txt) for full text).

[Genesys 2 FPGA board]: https://digilent.com/shop/genesys-2-amd-kintex-7-fpga-development-board
