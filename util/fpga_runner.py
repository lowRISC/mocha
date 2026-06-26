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

FTDI_PID: int = 0x6010
BAUD_RATE: int = 1_000_000
FTDITOOL_WAIT_TIME: int = 60
FTDI_DEVICE_DESC = "Digilent"
MOCHA_BOOTSTAP_PATTERN = re.compile(r"Entering SPI bootstrap")
TEST_PATTERN = re.compile(r"TEST RESULT: (PASSED|FAILED)", re.IGNORECASE)

RUNNER: str = Path(__file__).stem


def error(what: str, why: str) -> None:
    print(f"[{RUNNER}]: {what}: {why}", file=sys.stderr)


def ftditool_command(cmd: str) -> list[str]:
    """Common `ftditool` commandline arguments."""
    return [
        "ftditool",
        "--pid",
        hex(FTDI_PID),
        cmd,
        "--ftdi",
        FTDI_DEVICE_DESC,
    ]


async def set_pin(pin: int, val: bool) -> None:
    command = ftditool_command("gpio-write")
    command.extend([str(pin), str(int(val))])

    p = await asyncio.create_subprocess_exec(*command)
    try:
        res = await asyncio.wait_for(p.wait(), FTDITOOL_WAIT_TIME)
        if res:
            error("ftditool gpio-write", f"exited with non-zero exit code {p.returncode}")
            sys.exit(1)
    except TimeoutError:
        error("ftditool gpio-write", f"timed out after {FTDITOOL_WAIT_TIME} seconds")
        await p.terminate()  # or maybe p.kill()
        sys.exit(1)


async def reset_core() -> None:
    """
    Reset the core by pulling the reset pin down for 100ms.
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


async def load_elf(path: Path) -> None:
    command = ftditool_command("load-elf")
    command.append(str(path))

    p = await asyncio.create_subprocess_exec(*command)
    if await p.wait() != 0:
        error("ftditool load-elf", f"exited with non-zero exit code {p.returncode}")
        sys.exit(1)


async def load_binary(path: Path, address: int) -> None:
    command = ftditool_command("load-file")
    command.extend(["--skip-erase", str(path), "--addr", hex(address)])

    p = await asyncio.create_subprocess_exec(*command)
    if await p.wait() != 0:
        error("ftditool load-file", f"exited with non-zero exit code {p.returncode}")
        sys.exit(1)


async def exit_bootstrap() -> None:
    """
    Exit SPI bootstrap mode on the FPGA by sending a flash reset command to the
    emulated flash, causing the board to jump into uploaded code.
    """
    command = ftditool_command("flash-reset")
    p = await asyncio.create_subprocess_exec(*command)
    if await p.wait() != 0:
        error("ftditool flash-reset", f"exited with non-zero exit code {p.returncode}")
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


async def do_fpga_load(args) -> None:
    """
    Load all binaries and ELFs provided by the '-f' and '-e' flags onto the
    FPGA, and then send a reset command to the emulated flash to exit SPI
    bootstrap mode.
    """
    for binary, address in args.bins:
        print(f"loading binary '{binary}' at address 0x{address:x}...")
        await load_binary(binary, address)
    for elf in args.elfs:
        print(f"loading ELF '{elf}'...")
        await load_elf(elf)
    await exit_bootstrap()


async def do_fpga_test(args) -> None:
    """
    Test subcommand.
    Load the binaries/ELFs onto the FPGA, then poll for the test result pattern.
    """
    if uart_tty := find_uart():
        with serial.Serial(uart_tty, BAUD_RATE, timeout=0) as uart:
            print("bootstrapping...")
            await bootstrap(uart)
            await do_fpga_load(args)
            result = await poll_uart_checking_for(uart, TEST_PATTERN)
            if "PASSED" in result:
                sys.exit(0)  # test success
            sys.exit(1)

    error("test", "UART not found")
    sys.exit(1)


async def do_fpga_run(args) -> None:
    """
    Run subcommand.
    Just load the binaries/ELFs onto the FPGA without opening the UART,
    so that it can remain open in a separate application (e.g screen, picocom).
    """
    print("bootstrapping...")
    await bootstrap(None)
    await do_fpga_load(args)
    sys.exit(0)


class BinaryAddressPairAction(argparse.Action):
    """
    Parser append action for binary/address pairs for the '-f' flag.
    """

    def __call__(self, parser, namespace, values, option_string=None):
        binary, address = values
        try:
            result = (Path(binary), int(address, 0))
        except ValueError as e:
            raise argparse.ArgumentError(self, f"Invalid address '{address}'") from e

        val = getattr(namespace, self.dest, None)
        if val is None:
            val = []
        val.append(result)
        setattr(namespace, self.dest, val)


def main() -> None:
    parser = argparse.ArgumentParser(description="FPGA test runner")
    subparsers = parser.add_subparsers(dest="command", required=True, help="Subcommands")

    test_help = (
        "Load binaries/ELFs onto the FPGA, then poll the UART for a test result. "
        "Captures output from the UART."
    )

    test_parser = subparsers.add_parser("test", help=test_help, description=("test: " + test_help))
    test_parser.set_defaults(func=do_fpga_test)

    run_help = (
        "Load binaries/ELFs onto the FPGA, then exit. This subcommand does not use the UART, "
        "so that it can be kept open in a separate program (e.g screen, picocom) for "
        "interactive use."
    )

    run_parser = subparsers.add_parser("run", help=run_help, description=("run: " + run_help))
    run_parser.set_defaults(func=do_fpga_run)

    for p in [test_parser, run_parser]:
        p.add_argument(
            "-e",
            "--elf",
            dest="elfs",
            action="append",
            metavar="elf",
            default=[],
            help="ELF file to load.",
        )
        p.add_argument(
            "-f",
            "--file",
            dest="bins",
            action=BinaryAddressPairAction,
            nargs=2,
            metavar=("binary", "address"),
            default=[],
            help="Binary file to load at given address.",
        )

    args = parser.parse_args()
    if not args.elfs and not args.bins:
        parser.error("At least one binary or ELF file to load must be provided with '-e' or '-f'")

    try:
        asyncio.run(args.func(args))
    except KeyboardInterrupt:  # Suppress error traceback if interrupted by user with ctrl-c.
        sys.exit(1)


if __name__ == "__main__":
    main()
