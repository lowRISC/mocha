#!/usr/bin/env python
# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import asyncio
import re
import sys
from pathlib import Path

import serial
import serial.tools.list_ports
from elftools.elf.elffile import ELFFile

FTDI_PID: int = 0x6010
BAUD_RATE: int = 1_000_000
FTDITOOL_WAIT_TIME: int = 60
FTDI_DEVICE_DESC = "Digilent"
MOCHA_BOOTSTAP_PATTERN = re.compile(r"Entering SPI bootstrap")
TEST_PATTERN = re.compile(r"TEST RESULT: (PASSED|FAILED)", re.IGNORECASE)

RUNNER: str = Path(__file__).name


async def set_pin(pin: int, val: bool) -> None:
    command = [
        "ftditool",
        "--pid",
        hex(FTDI_PID),
        "gpio-write",
        str(pin),
        str(int(val)),
        "--ftdi",
        FTDI_DEVICE_DESC,
    ]

    p = await asyncio.create_subprocess_exec(*command)
    try:
        res = await asyncio.wait_for(p.wait(), FTDITOOL_WAIT_TIME)
        if res:
            print(f"[{RUNNER}] gpio-write command exited with non-zero exit code {p.returncode}")
            sys.exit(1)
    except TimeoutError:
        print(f"[{RUNNER}] gpio-write timed out after {FTDITOOL_WAIT_TIME} seconds.")
        await p.terminate()  # or maybe p.kill()
        sys.exit(1)


async def reset_core() -> None:
    """
    Pull the reset pin down for 100ms.
    """
    await set_pin(2, False)
    await asyncio.sleep(0.1)
    await set_pin(2, True)


async def bootstrap(uart: serial.Serial | None) -> None:
    """
    Pull down the bootstrap pin and reset the core. If a UART is provided,
    wait for the bootstrap string over UART, otherwise wait a short period
    of time and assume the system is ready for bootstrapping. Then release the pin.
    """
    await set_pin(0, False)
    await reset_core()
    if uart is not None:
        await poll_uart_checking_for(uart, MOCHA_BOOTSTAP_PATTERN)
    else:
        await asyncio.sleep(0.5)
    await set_pin(0, True)


def get_load_addr(elf: Path) -> int:
    try:
        with elf.open("rb") as f:
            elf = ELFFile(f)
            load_addrs = [
                seg["p_paddr"] for seg in elf.iter_segments() if seg["p_type"] == "PT_LOAD"
            ]
            if not load_addrs:
                print(f"[{RUNNER}] no `PT_LOAD` segments found in elf {elf}")
                sys.exit(1)

            first_address = min(load_addrs)
            return first_address
    except OSError as e:
        print(f"[{RUNNER}] error opening elf {elf}: {e}")
        sys.exit(1)


async def load_fpga_binary(path: Path, uart: serial.Serial | None) -> None:
    load_address = get_load_addr(path)

    await bootstrap(uart)

    command = [
        "ftditool",
        "--pid",
        hex(FTDI_PID),
        "bootstrap",
        "--addr",
        hex(load_address),
        "--ftdi",
        FTDI_DEVICE_DESC,
    ]
    command.append(str(path.with_suffix(".bin")))

    p = await asyncio.create_subprocess_exec(*command)
    if await p.wait() != 0:
        print(f"[{RUNNER}] SPI load command exited with non-zero exit code {p.returncode}")
        sys.exit(1)


async def poll_uart_checking_for(uart: serial.Serial, pattern: re.Pattern) -> str:
    while True:
        line = await asyncio.to_thread(uart.readline)
        line = line.decode("utf-8", errors="ignore")
        print(line, end="")
        if not line:
            continue
        if match := pattern.search(line):
            return match.group()


def find_uart(vid: int = 0x0403, pid: int = 0x6001) -> str | None:
    for port in serial.tools.list_ports.comports():
        if port.vid == vid and port.pid == pid:
            return port.device
    return None


async def do_fpga_test(args) -> None:
    """
    Test subcommand.
    Load the binary onto the FPGA, then poll for the test result pattern.
    """
    if uart_tty := find_uart():
        with serial.Serial(uart_tty, BAUD_RATE, timeout=0) as uart:
            await load_fpga_binary(args.path, uart)

            result = await asyncio.create_task(poll_uart_checking_for(uart, TEST_PATTERN))
            if "PASSED" in result:
                sys.exit(0)  # test success
            sys.exit(1)

    print(f"[{RUNNER}] Error: UART device not found")
    sys.exit(1)


async def do_fpga_run(args) -> None:
    """
    Run subcommand.
    Just load the binary onto the FPGA without opening the UART,
    so that it can remain open in a separate application (e.g screen).
    """
    await load_fpga_binary(args.path, None)
    sys.exit(0)


def main() -> None:
    parser = argparse.ArgumentParser(description="FPGA test runner")
    subparsers = parser.add_subparsers(dest="command", required=True, help="Subcommands")

    test_help = (
        "Load a binary on the FPGA, then poll the UART for a test result. "
        "Captures output from the UART."
    )

    test_parser = subparsers.add_parser("test", help=test_help, description=("test: " + test_help))
    test_parser.add_argument("path", type=Path, help="Path to test ELF to test on the FPGA")
    test_parser.set_defaults(func=do_fpga_test)

    run_help = (
        "Load a binary on the FPGA, then exit. This subcommand does not use the UART, "
        "so that it can be kept open in a separate program (e.g screen) for "
        "interactive use."
    )

    run_parser = subparsers.add_parser("run", help=run_help, description=("run: " + run_help))
    run_parser.add_argument("path", type=Path, help="Path to program ELF to run on the FPGA")
    run_parser.set_defaults(func=do_fpga_run)

    args = parser.parse_args()
    try:
        asyncio.run(args.func(args))
    except KeyboardInterrupt:
        sys.exit(1)


if __name__ == "__main__":
    main()
