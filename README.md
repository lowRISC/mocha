# CHERI Mocha

The CHERI Mocha project is a reference design for an integrated SoC subsystem for secure enclaves that use CHERI.
Secure enclaves are usually part of a larger SoC and are tasked with security critical tasks like user authentication, password storage, etc.
These enclave systems often include application class processors because they need to support an MMU-enabled operating system, usually based on L4 or something clean slate, as opposed to real-time operating systems.
Rich operating systems require virtual memory and page table permissions.
CHERI is an important technology to evaluate in these systems because of the high-level of confidentiality, integrity and availability that is required here.
This open-source design is meant to be a reference for ASICs with any proprietary primitives clearly stubbed out and isolated.
Specifically, any hardware that requires changes with respect to CHERI should be in the open source since this is critical to providing a production-grade CHERI-enabled subsystem that can be integrated into an ASIC.

CHERI Mocha is part of the COSMIC project, which is a collaboration between lowRISC, Capabilities Limited and Oxford University Innovation.
It is work that is funded by Innovate UK and the Department for Science, Innovation and Technology.

## Architecture

The Mocha architecture contains two crossbars.
One crossbar is capability width and is meant for the main memory.
The other crossbar is uncached and meant to contain the peripherals.
Because most of these peripherals are imported from OpenTitan, in the first instance this bus is implemented as a TileLink Ultra-Lightweight bus with 32 width.

![Mocha block diagram](doc/img/mocha.svg)

### Memory map

This is the current memory map for Mocha, where the base and top addresses are inclusive, and reserved is the amount of memory reserved for this function:

| Base address  | Top address   | Reserved | Function     |
|---------------|---------------|----------|--------------|
| `0x0000_8000` | `0x0008_FFFF` |  128 KiB | ROM          |
| `0x1000_0000` | `0x1001_FFFF` |  256 MiB | SRAM         |
| `0x2000_0000` | `0x2000_0FFF` |   64 KiB | Debug module |
| `0x4000_0000` | `0x4000_0047` |   64 KiB | GPIO         |
| `0x4001_0000` | `0x4001_0043` |   64 KiB | Mailbox      |
| `0x4100_0000` | `0x4100_0033` |   16 MiB | UARTs        |
| `0x4200_0000` | `0x4200_001F` |   16 MiB | I2C hosts    |
| `0x4300_0000` | `0x4300_1FBF` |   16 MiB | SPI devices  |
| `0x4400_0000` | `0x4400_FFFF` |   16 MiB | Timer        |
| `0x4800_0000` | `0x4BFF_FFFF` |   64 MiB | PLIC         |
| `0x8000_0000` | `0xBFFF_FFFF` |    2 GiB | DRAM         |

## Developer guide

### Setup Python virtual environment

#### Using uv on macOS and Linux

```sh
# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# Create the virtual environment.
uv venv
uv sync --all-extras

# Enter the environment (do it every time).
source .venv/bin/activate
```

#### Using Nix or NixOS

```sh
nix develop
```

Alternatively if you are using `direnv` then this can be automated by enabling `direnv`.

```sh
direnv allow .
```

When entering the directory from then on you will automatically enter the dev shell.
Changing directory outside the repository root will deactivate the dev shell for you.

### Software

#### Build

Software binaries are built using CMake.

```sh
# Setup the buildsystem.
cmake -B build/sw -S sw
# Build the software.
cmake --build build/sw -j $(nproc)
```

#### Code Quality

For software written in C, `clang-format` and `clang-tidy` are used format and lint the code. Wrapper scripts to run these on all C files in the project are provided for convenience.

To format and lint, run:
```sh
# Format all C files.
util/clang_format.py
# Lint all C files.
util/clang_tidy.py
```

### Simulation

We use Verilator to simulate our hardware design and use FuseSoC as a build system:
```sh
# Build simulator.
fusesoc --cores-root=. run --target=sim --tool=verilator --setup --build lowrisc:mocha:top_chip_system
# Run simulator.
build/lowrisc_mocha_top_chip_system_0/sim-verilator/Vtop_chip_verilator -t -E build/sw/device/examples/hello_world/hello_world
```

One specific feature of our simulator is that you can exit the simulation by using the following magic string:
`Safe to exit simulator.\xd8\xaf\xfb\xa0\xc7\xe1\xa9\xd7`


To run the verilator tests, first build the software, then run:
```sh
ctest --test-dir build/sw -R sim_verilator
```

### FPGA

#### OpenFPGALoader

One way to program your FPGA is to use openFPGALoader.
In Linux you must allow openFPGALoader to access your USB device.
First copy the example rules file in this repository and execute some commands for the rules to take effect:
```sh
cp util/99-openfpgaloader.rules /etc/udev/rules.d/99-openfpgaloader.rules
sudo udevadm control --reload-rules
sudo udevadm trigger
sudo usermod -a $USER -G plugdev
```

#### Build bitstream

Make sure that Vivado is on your path, then run:
```sh
fusesoc --cores-root=. run --target=synth --setup --build lowrisc:mocha:chip_mocha_genesys2 --BootRomInitFile=$PWD/build/sw/device/examples/hello_world/hello_world.vmem
```

#### Test on Genesys2

Open a UART terminal with 921600 baud rate:
```sh
screen /dev/ttyUSB0 921600
```
You may have to change the ttyUSB number.

Then load the bitstream onto Genesys 2:
```sh
openFPGALoader -b genesys2 build/lowrisc_mocha_chip_mocha_genesys2_0/synth-vivado/lowrisc_mocha_chip_mocha_genesys2_0.bit
```

## License

This project is licensed under the Apache License, Version 2.0.

This license, as well as the licenses of all vendored sub-projects, can be found in the `LICENSES` sub-directory.

All code files must start with the following header (in the comment style applicable for the language):
```c
// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
```

For files that are generated by code or otherwise cannot have comments added to them (e.g images, lock files, markdown),
this information should be specified in the top-level `REUSE.toml`, but this should be used sparingly.
The `hw/vendor` directory contains its own `REUSE.toml` for vendored sub-projects.

To check that all files contain copyright and licensing information, run:
```sh
reuse lint
```
