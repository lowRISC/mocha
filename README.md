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

### Simulation

```sh
# Build simulator.
fusesoc --cores-root=. run --target=sim --tool=verilator --setup --build lowrisc:mocha:top_chip_system
# Run simulator.
build/lowrisc_mocha_top_chip_system_0/sim-verilator/Vtop_chip_verilator -t -E sw/device/examples/hello_world/hello_world.elf
```

### Temporary software flow

```sh
pushd sw/device/examples/hello_world
./build.sh
popd
```
