#!/usr/bin/env python
# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import asyncio
import re
import sys
import time
from pathlib import Path

import serial
import serial.tools.list_ports
from elftools.elf.elffile import ELFFile

FTDI_PID: int = 0x6010
BAUD_RATE: int = 1_000_000
TIMEOUT: int = 60
FTDITOOL_WAIT_TIME: int = 60
FTDI_DEVICE_DESC = "Digilent"
MOCHA_BOOTROM_BOOSTRAP_STR = "Entering SPI bootstrap"

RUNNER: str = Path(__file__).name


async def set_pin(pin: int, val: int) -> None:
    command = [
        "ftditool",
        "--pid",
        hex(FTDI_PID),
        "gpio-write",
        str(pin),
        str(val),
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
    await set_pin(2, 0)
    await asyncio.sleep(0.1)
    await set_pin(2, 1)


async def bootstrap(uart: serial.Serial) -> bool:
    """
    Pull down the bootstrap pin, reset the core, wait for the bootstrap string over uart,
    then release the pin the bootstrap pin.
    """
    await set_pin(0, 0)
    await reset_core()
    result = await poll_uart_checking_for(uart, MOCHA_BOOTROM_BOOSTRAP_STR)
    await set_pin(0, 1)
    return result is not None


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


async def load_fpga_test(test: Path, uart) -> None:
    await bootstrap(uart)
    command = [
        "ftditool",
        "--pid",
        hex(FTDI_PID),
        "bootstrap",
        "--addr",
        hex(get_load_addr(test)),
        "--ftdi",
        FTDI_DEVICE_DESC,
    ]
    command.append(str(test.with_suffix(".bin")))
    p = await asyncio.create_subprocess_exec(*command)
    if await p.wait() != 0:
        print(f"[{RUNNER}] SPI load command exited with non-zero exit code {p.returncode}")
        sys.exit(1)


async def run_fpga_test(tty: str, test: Path) -> bool:
    with serial.Serial(tty, BAUD_RATE, timeout=0) as uart:
        await load_fpga_test(test, uart)
        pattern = r"TEST RESULT: (PASSED|FAILED)"
        result = await asyncio.create_task(poll_uart_checking_for(uart, pattern))
        return result and "PASSED" in result


async def poll_uart_checking_for(uart: serial.Serial, pattern: str) -> str | None:
    pattern = re.compile(pattern, re.IGNORECASE)
    start = time.time()
    while time.time() - start < TIMEOUT:
        line = await asyncio.to_thread(uart.readline)
        line = line.decode("utf-8", errors="ignore")
        print(line, end="")
        if not line:
            continue
        if match := pattern.search(line):
            return match.group()
    print(f"[{RUNNER}] Test timeout")
    return None


def find_uart(vid: int = 0x0403, pid: int = 0x6001) -> str | None:
    for port in serial.tools.list_ports.comports():
        if port.vid == vid and port.pid == pid:
            return port.device
    return None


def main() -> None:
    parser = argparse.ArgumentParser(description="FPGA test runner")
    parser.add_argument("test", type=Path, help="path to test")
    args = parser.parse_args()

    if uart_tty := find_uart():
        try:
            success = asyncio.run(run_fpga_test(uart_tty, args.test))
            sys.exit(0 if success else 1)
        except KeyboardInterrupt:
            sys.exit(1)

    print(f"[{RUNNER}] Error: UART device not found")
    sys.exit(1)


if __name__ == "__main__":
    main()
