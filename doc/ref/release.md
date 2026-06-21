# Release procedure

This document describes the release procedure for CHERI Mocha.
It enumerates all the checks we do before we make an official release.
The procedure will be updated over time as the project evolves.

## Sign-off reviews

Check the sign-offs that have happened since the last release and double-check that each pull request was approved by three reviewers.

## Check out repository

Make sure to check out a clean repository:
```sh
mkdir mocha-release
cd mocha-release
git clone git@github.com:lowRISC/mocha.git
cd mocha
nix develop
```

## Software

Make sure all software builds cleanly:
```sh
cmake -B build/sw -S sw
cmake --build build/sw -j $(nproc)
```

## Bitstream

Build the bitstream locally:
```sh
fusesoc --cores-root=. run --target=synth --setup --build lowrisc:mocha:chip_mocha_genesys2 --RomInitFile=$PWD/build/sw/device/bootrom/bootrom_scrambled.vmem
# Nix alternative: `nix run .#bitstream-build`
cp build/lowrisc_mocha_chip_mocha_genesys2_0/synth-vivado/lowrisc_mocha_chip_mocha_genesys2_0.bit release.bit
```

Double check that there are no errors or critical warnings for example by checking the output of:
```sh
find -name "runme.log" | xargs grep "ERROR"
```
Expected output:
```
./build/lowrisc_mocha_chip_mocha_genesys2_0/synth-vivado/lowrisc_mocha_chip_mocha_genesys2_0.runs/impl_1/runme.log:WARNING: [Place 30-575] Sub-optimal placement for a clock-capable IO pin and MMCM pair. This is normally an ERROR but the CLOCK_DEDICATED_ROUTE constraint is set to FALSE allowing your design to continue. The use of this override is highly discouraged as it may lead to very poor timing results. It is recommended that this error condition be corrected in the design.
./build/lowrisc_mocha_chip_mocha_genesys2_0/synth-vivado/lowrisc_mocha_chip_mocha_genesys2_0.runs/impl_1/runme.log: This is normally an ERROR but the CLOCK_DEDICATED_ROUTE constraint is set to FALSE allowing your design to continue. The use of this override is highly discouraged as it may lead to very poor timing results. It is recommended that this error condition be corrected in the design.
```
Then check for critical warnings:
```sh
find -name "runme.log" | xargs grep -i "CRITICAL WARNING"
```
Expected output:
```
./build/lowrisc_mocha_chip_mocha_genesys2_0/synth-vivado/lowrisc_mocha_chip_mocha_genesys2_0.runs/u_xlnx_mig_7_ddr3_synth_1/runme.log:Synthesis finished with 0 errors, 0 critical warnings and 1 warnings.
./build/lowrisc_mocha_chip_mocha_genesys2_0/synth-vivado/lowrisc_mocha_chip_mocha_genesys2_0.runs/u_xlnx_mig_7_ddr3_synth_1/runme.log:254 Infos, 34 Warnings, 0 Critical Warnings and 0 Errors encountered.
./build/lowrisc_mocha_chip_mocha_genesys2_0/synth-vivado/lowrisc_mocha_chip_mocha_genesys2_0.runs/impl_1/runme.log:10 Infos, 0 Warnings, 0 Critical Warnings and 0 Errors encountered.
./build/lowrisc_mocha_chip_mocha_genesys2_0/synth-vivado/lowrisc_mocha_chip_mocha_genesys2_0.runs/impl_1/runme.log:38 Infos, 0 Warnings, 0 Critical Warnings and 0 Errors encountered.
./build/lowrisc_mocha_chip_mocha_genesys2_0/synth-vivado/lowrisc_mocha_chip_mocha_genesys2_0.runs/impl_1/runme.log:81 Infos, 43 Warnings, 0 Critical Warnings and 0 Errors encountered.
./build/lowrisc_mocha_chip_mocha_genesys2_0/synth-vivado/lowrisc_mocha_chip_mocha_genesys2_0.runs/impl_1/runme.log:91 Infos, 43 Warnings, 0 Critical Warnings and 0 Errors encountered.
./build/lowrisc_mocha_chip_mocha_genesys2_0/synth-vivado/lowrisc_mocha_chip_mocha_genesys2_0.runs/impl_1/runme.log:108 Infos, 44 Warnings, 0 Critical Warnings and 0 Errors encountered.
./build/lowrisc_mocha_chip_mocha_genesys2_0/synth-vivado/lowrisc_mocha_chip_mocha_genesys2_0.runs/impl_1/runme.log:121 Infos, 45 Warnings, 0 Critical Warnings and 0 Errors encountered.
./build/lowrisc_mocha_chip_mocha_genesys2_0/synth-vivado/lowrisc_mocha_chip_mocha_genesys2_0.runs/impl_1/runme.log:13 Infos, 196 Warnings, 0 Critical Warnings and 0 Errors encountered.
./build/lowrisc_mocha_chip_mocha_genesys2_0/synth-vivado/lowrisc_mocha_chip_mocha_genesys2_0.runs/synth_1/runme.log:Synthesis finished with 0 errors, 0 critical warnings and 78187 warnings.
./build/lowrisc_mocha_chip_mocha_genesys2_0/synth-vivado/lowrisc_mocha_chip_mocha_genesys2_0.runs/synth_1/runme.log:1189 Infos, 528 Warnings, 0 Critical Warnings and 0 Errors encountered.
```

Program the FPGA:
```sh
openFPGALoader -b genesys2 release.bit
# Nix alternative:
#nix run .#bitstream-load release.bit
```
Check that the default behavior is that the LEDs are flashing.

Run the FPGA tests and make sure they all pass (assuming you have the I2C temperature sensor and SD card plugged in):
```sh
ctest --test-dir build/sw -R fpga -LE slow --output-on-failure
```

Run CHERI Linux:
```sh
# Connect to UART:
picocom $(ls /dev/serial/by-id/usb-FTDI_FT232R_USB_UART_*-port0) -b 1000000 --imap lfcrlf
# In another terminal, load OpenSBI, U-Boot, the Linux kernel and a root filesystem:
nix run .#fpga-runner -- run -e build/sw/opensbi_with_uboot/opensbi_with_uboot_fw_payload.elf -f build/sw/linux/linux_image 0x90000000 -f build/sw/rootfs_uboot_image 0xa0000000
```

Once boot is successful, check that the output is correct (substituting in the right values for `<...>`):
```
~ # uname -a
Linux Mocha <version>-<hash> #1 <date> <time> <year> riscv64 riscv64 riscv64 GNU/Linux
```

## Simulation

Make sure the simulation builds:
```sh
fusesoc --cores-root=. run --target=sim --tool=verilator --setup --build lowrisc:mocha:top_chip_verilator --verilator_options="--threads 2 --trace-threads 2" --make_options="-j 8"
```

Run all the tests and make sure they all pass:
```sh
ctest --test-dir build/sw -R sim_verilator --output-on-failure
```

Check that OpenSBI still boots on Verilator:
```sh
tail -f uart0.log
# In a separate terminal run the simulator
build/lowrisc_mocha_top_chip_verilator_0/sim-verilator/Vtop_chip_verilator -r build/sw/device/bootrom/bootrom_scrambled.vmem -E build/sw/opensbi_with_opensbi_test_payload/opensbi_with_opensbi_test_payload_fw_payload.elf
```

You should see the OpenSBI logo appear over UART:
```
OpenSBI v1.5
   ____                    _____ ____ _____
  / __ \                  / ____|  _ \_   _|
 | |  | |_ __   ___ _ __ | (___ | |_) || |
 | |  | | '_ \ / _ \ '_ \ \___ \|  _ < | |
 | |__| | |_) |  __/ | | |____) | |_) || |_
  \____/| .__/ \___|_| |_|_____/|____/_____|
        | |
        |_|
```
You should also check that the [nightly check](https://github.com/lowRISC/mocha/actions/workflows/nightly.yml) on the same commit passed.

## Verification

Make sure there are no unexpected errors on the latest nightly dashboard.
Run the top-level smoketests to confirm:
```sh
dvsim hw/top_chip/dv/top_chip_sim_cfg.hjson -i smoke -t xcelium
```

## Making a release

### Create a tag

```sh
git tag vX.Y.Z
git push origin vX.Y.Z
```

### Generate artefacts

Then create a pre-release which should trigger the [release action](https://github.com/lowRISC/mocha/actions/workflows/release.yml) to generate all the files necessary for the release.
Enter the release notes based on the template below and make sure to download all the files to test the quick start guide before making it an actual release.

### Release notes

You should base the release notes on the [example template](release_notes_template.md).
