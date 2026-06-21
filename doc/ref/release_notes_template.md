# Example release notes for Mocha

The COSMIC team is pleased to announce this release of the Mocha repository.

The release contains a bitstream which you can flash on the Genesys 2 board `lowrisc_mocha_chip_mocha_genesys2_0.bit`, a utilisation report `chip_mocha_genesys2_utilization_placed.rpt`, a set of USB rules for FPGA programming `99-openfpgaloader.rules`, a built Verilator simulator `Vtop_chip_verilator`, a build of example software `release_software.tar.gz` (including boot ROM and Linux artefacts) and an environment to program the FPGA (`flake.nix` and `fpga_runner.py`).

## Quick start

Firstly download all the artefacts to the same directory and change to that directory. Then follow these steps to test on FPGA:

1. Install dependencies:
    - OpenFPGALoader, for example: `apt install openfpgaloader`
    - Picocom, for example: `apt install picocom`
    - Nix, for example: `curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh -s -- --daemon` and adding support for Flake  by adding `experimental-features = nix-command flakes` to your Nix configuration (e.g. `/etc/nix/nix.conf`)
1. Connect your Genesys 2 board with the POWER, UART and JTAG. Make sure to turn on the board using SW8.
1. Configure udev rules:
    ```sh
    cp 99-openfpgaloader.rules /etc/udev/rules.d/99-openfpgaloader.rules
    udevadm control --reload-rules
    udevadm trigger
    usermod -a -G plugdev $USER
    ```
1. Program the downloaded bitstream:
    ```sh
    openFPGALoader -b genesys2 lowrisc_mocha_chip_mocha_genesys2_0.bit
    ```
1. Extract the example software:
    ```sh
    tar -xzvf release_software.tar.gz
    ```
1. Look at UART output:
    ```sh
    picocom $(ls /dev/serial/by-id/usb-FTDI_FT232R_USB_UART_*-port0) -b 1000000 --imap lfcrlf
    ```
1. In another terminal, load all the requirements to boot Linux:
    ```sh
    nix run .#fpga-runner -- run -e release/opensbi_with_uboot_fw_payload.elf -f release/linux_image 0x90000000 -f release/rootfs_uboot_image 0xa0000000
    ```
    You should see lots of output including `Welcome to CHERI Mocha!`. You can then use any command supported by busybox, such as:
    ```
    ~ # uname -a
    Linux Mocha <version>-<hash> #1 <date> <time> <year> riscv64 riscv64 riscv64 GNU/Linux
    ```
    This shows you a full flow of OpenSBI, U-Boot, the Linux kernel and a root filesystem loading on CHERI Mocha!

In simulation you can do the following:
1. Make the simulator executable and run the hello world example by running the following command:
    ```sh
    chmod +x Vtop_chip_verilator
    ./Vtop_chip_verilator -r release/bootrom_scrambled.vmem -E release/examples/hello_world
    ```
1. Check the UART output:
    ```sh
    cat uart0.log
    ```
    Which should contain content including "Hello CHERI Mocha!"

Please refer to the full [developer guide](https://github.com/lowRISC/mocha/blob/main/doc/ref/dev_guide.md) for instructions on how to build the simulator, software and bitstream from source.
