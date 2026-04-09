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

BOOT_ROM_OFFSET: int = 0x4000
BAUD_RATE: int = 1_000_000
TIMEOUT: int = 60

RUNNER: str = Path(__file__).name


async def load_fpga_test(test: Path) -> None:
    command = ["openFPGALoader", "--spi", "--offset", str(BOOT_ROM_OFFSET), "--write-flash"]
    command.append(str(test.with_suffix(".bin")))
    p = await asyncio.create_subprocess_exec(*command)
    if await p.wait() != 0:
        print(f"[{RUNNER}] SPI load command exited with non-zero exit code {p.returncode}")
        sys.exit(1)
    # TODO: This is a workaround to send a reset and start the test, should be removed when we
    # are able to reset the SoC with the external reset.
    # The first invocation resets and load the binary, the second resets and the load is
    # ignored by the bootROM, thus we don't check the return error.
    p = await asyncio.create_subprocess_exec(*command)
    await p.wait()


async def run_fpga_test(tty: str, test: Path) -> bool:
    with serial.Serial(tty, BAUD_RATE, timeout=0) as uart:
        load = asyncio.create_task(load_fpga_test(test))
        await load
        poll = asyncio.create_task(poll_uart_checking_for(uart, r"TEST RESULT: (PASSED|FAILED)"))
        result = await poll
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
