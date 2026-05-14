# Developer guide

This page contains useful commands and tips on how to develop on the Mocha repository.
It collects both design, software and verification instructions.

## Quick start from release

Firstly download all the artefacts from a particular [release](https://github.com/lowRISC/mocha/releases).
Then follow the following steps to test on FPGA:

1. Install dependencies:
    - OpenFPGALoader, for example: `apt install openfpgaloader`
    - Screen, for example: `apt install screen`
2. Connect your Genesys 2 board with the POWER, UART and JTAG. Make sure to turn on the board using SW8.
3. Configure udev rules (you might need admin rights for these):
    ```sh
    cp 99-openfpgaloader.rules /etc/udev/rules.d/99-openfpgaloader.rules
    udevadm control --reload-rules
    udevadm trigger
    usermod -a -G plugdev $USER
    ```
4. Program the downloaded bitstream:
    ```sh
    openFPGALoader -b genesys2 lowrisc_mocha_chip_mocha_genesys2_0.bit
    ```
5. Look at UART output:
    ```sh
    screen $(ls /dev/serial/by-id/usb-FTDI_FT232R_USB_UART_*-port0) 1000000
    ```
    You should press the RESET button on the Genesys 2 board (BTN1) to see bootloader message "Boot ROM!". To exit screen press `ctrl`-`a` then `k` and confirm with `y`.

In simulation you can do the following:
1. Extract the example software:
    ```sh
    tar -xzvf examples.tar.gz
    ```
2. Make the simulator executable and run the "hello world" by running the following command:
    ```sh
    chmod +x Vtop_chip_verilator
    ./Vtop_chip_verilator -E release/hello_world_verilator
    ```
3. Check the UART output:
    ```sh
    cat uart0.log
    ```
    Which should contain content including "Hello CHERI Mocha!"

Programming new software over SPI is also possible using the boot ROM. Here are the steps to run the hello world example:
1. Open up a screen terminal in parallel:
    ```sh
    screen $(ls /dev/serial/by-id/usb-FTDI_FT232R_USB_UART_*-port0) 1000000
    ```
2. In another terminal program the SPI. Note you must run this command twice, and it is expected that the second run reports "Fail":
    ```sh
    openFPGALoader --spi --offset 0x4000 --write-flash release/hello_world.bin
    openFPGALoader --spi --offset 0x4000 --write-flash release/hello_world.bin
    ```
    In the terminal where you opened screen you should see the following output:
    ```

    Boot ROM!

    First reset
    Jumping to: 0x%0x
    Hello CHERI Mocha!
    timer 100us
    timer 100us
    timer 100us
    timer 100us
    ```

## Setup Python virtual environment

### Using uv on macOS and Linux

```sh
# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# Create the virtual environment.
uv venv
uv sync --all-extras

# Enter the environment (do it every time).
source .venv/bin/activate
```

### Using Nix or NixOS

```sh
nix develop
```

Alternatively if you are using `direnv` then this can be automated by enabling `direnv`.

```sh
direnv allow .
```

When entering the directory from then on you will automatically enter the dev shell.
Changing directory outside the repository root will deactivate the dev shell for you.

## Software

### Build

Mocha software binaries are built using CMake.

To build all software binaries, run:
```sh
# Setup the buildsystem.
cmake -B build/sw -S sw
# Build the software.
cmake --build build/sw -j $(nproc)
```

Outputs with the suffix "_sram" exist only for UVM-based tests, as they presently lack a DRAM backdoor-load mechanism.

### Code Quality

For software written in C, `clang-format` and `clang-tidy` are used to format and lint the code.
Wrapper scripts to run these on all C files in the project are provided for convenience.

To format and lint, run:
```sh
# Format all C files.
util/clang_format.py
# Lint all C files.
util/clang_tidy.py
```

## Simulation

We use Verilator to simulate our hardware design and use FuseSoC as a build system.

To build and run a Verilator simulation of Mocha, run:
```sh
# Build simulator.
fusesoc --cores-root=. run --target=sim --tool=verilator --setup --build lowrisc:mocha:top_chip_verilator --verilator_options="-j 4 --threads 2 --trace-threads 2" --make_options="-j 4"
# Run simulator.
build/lowrisc_mocha_top_chip_verilator_0/sim-verilator/Vtop_chip_verilator -E build/sw/device/bootrom/bootrom -E build/sw/device/examples/hello_world
```

Note that the `-j 4` arguments speed up simulator building, while the `--threads 2 --trace-threads 2` arguments speed up simulator running.
For maximum tracing performance, omit `--threads 2`.
For maximum non-tracing performance, or when using Verilator v5.048 onwards, omit `--trace-threads 2`.

One specific feature of our simulator is that you can exit the simulation by using the following magic string:
`Safe to exit simulator.\xd8\xaf\xfb\xa0\xc7\xe1\xa9\xd7`

To run the Verilator tests, first build the software, then run:
```sh
ctest --test-dir build/sw -R sim_verilator
```

## FPGA

### OpenFPGALoader

One way to program your FPGA is to use openFPGALoader.
In Linux you must allow openFPGALoader to access your USB device.
First copy the example rules file in this repository and execute some commands for the rules to take effect (you may need admin rights for the `udevadm` and `usermod` commands):
```sh
cp util/99-openfpgaloader.rules /etc/udev/rules.d/99-openfpgaloader.rules
udevadm control --reload-rules
udevadm trigger
usermod -a -G plugdev $USER
```

### Build bitstream

To build a bitstream with the boot-ROM, make sure that Vivado is on your path, then run:
```sh
fusesoc --cores-root=. run --target=synth --setup --build lowrisc:mocha:chip_mocha_genesys2 --RomInitFile=$PWD/build/sw/device/bootrom/bootrom.vmem
# Nix alternative: `nix run .#bitstream-build`
```

### Test on Genesys 2

To exercise a bitstream using a Genesys 2 board, perform the following steps.

Connect to the "UART" and "JTAG" USB ports on the Genesys 2 board.

Load the bitstream into the Genesys 2 FPGA:
```sh
openFPGALoader -b genesys2 build/lowrisc_mocha_chip_mocha_genesys2_0/synth-vivado/lowrisc_mocha_chip_mocha_genesys2_0.bit
# Nix alternative: `nix run .#bitstream-load`
```

Then, to load and run a single software binary on FPGA, first build the software, then run:
```sh
./util/fpga_runner.py build/sw/device/examples/hello_world
```

Or, to run all the FPGA tests, first build the software, then run:
```sh
ctest --test-dir build/sw -R fpga_genesys2
```

### Standalone UART

The UART output will be automatically presented when using `fpga_runner.py` or `ctest`, but otherwise requires a UART terminal.

Open a UART terminal with 1Mbps baud rate:
```sh
screen /dev/ttyUSB0 1000000
# Alternative: `picocom /dev/ttyUSB0 -b 1000000 --imap lfcrlf`
```
You may have to change the ttyUSB number.

### Additional hardware

Some peripheral tests require additional hardware to be connected to the Genesys 2 board:

- I^2C: AS6212 Temperature Sensor connected to header "JA" according to PMOD Interface Type 6 (I^2C).
  - i.e. header "JA" top-row left-to-right: VCC, GND, SDA, SCL, (NC), (NC)

## Verification

To run block-level verification you can use the following command:
```sh
dvsim hw/vendor/lowrisc_ip/ip/uart/dv/uart_sim_cfg.hjson -i uart_smoke -r 1 --tool xcelium
```

To run block-level formal verification you can use the following command:
```sh
dvsim hw/top_chip/formal/top_chip_fpv_ip_cfgs.hjson --select-cfgs rv_plic_fpv
```

To run top-level verification you can use the following command:
```sh
dvsim hw/top_chip/dv/mocha_sim_cfgs.hjson --tool xcelium
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
