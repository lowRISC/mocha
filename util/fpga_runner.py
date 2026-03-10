#!/usr/bin/env python
# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import subprocess
import sys
import time
from pathlib import Path

import serial
import serial.tools.list_ports

BOOT_ROM_OFFSET: int = 0x4000
BAUD_RATE: int = 1_000_000
TIMEOUT: int = 60


def load_fpga_test(test: Path, timeout: int = TIMEOUT) -> None:
    command = ["openFPGALoader", "--spi", "--offset", str(BOOT_ROM_OFFSET), "--write-flash"]
    command.append(test.with_suffix(".bin"))
    start = time.time()
    while time.time() - start < timeout:
        try:
            subprocess.run(command, capture_output=False, check=False)
        except OSError as e:
            print(f"[{Path(__file__).name}] Error: {e.strerror}")
            sys.exit(1)

        # TODO: This is a workaround to send a reset and start the test, should be removed when we
        # are able to reset the SoC with the external reset.
        # The first invocation resets and load the binary, the second resets and the load is
        # ignored by the bootROM, thus we don't check the return error.
        subprocess.run(command, capture_output=True, check=False)
        return

    print(f"[{Path(__file__).name}] Load FPGA test timeout")
    sys.exit(1)


def run_fpga_test(tty: str, test: Path, timeout: int = 10) -> int:
    print(f"Listening to {tty}")
    with serial.Serial(tty, BAUD_RATE, timeout=1) as uart:
        start = time.time()
        load_fpga_test(test)
        while time.time() - start < timeout:
            line = uart.readline().decode("utf-8", errors="ignore")
            print(line, end="")
            if not line or "TEST RESULT" not in line:
                continue

            if "PASSED" in line:
                return 0

            if "FAILED" not in line:
                print(f"[{Path(__file__).name}] Unknown test result: {line}")

            return 1
        print(f"[{Path(__file__).name}] Test timeout")
        return 1


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
        sys.exit(run_fpga_test(uart_tty, args.test, TIMEOUT))

    print(f"[{Path(__file__).name}] Error: UART device not found")
    sys.exit(1)


if __name__ == "__main__":
    main()
