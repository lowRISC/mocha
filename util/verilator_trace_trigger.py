#!/usr/bin/env python

# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""
Run a verilator simulation, streaming verilator log and UART output.
Optionally toggle tracing (SIGUSR1) when a trigger string appears on the UART.

The UART device path is extracted from the verilator log (a line in the
format "$ screen /dev/pts/N").

Usage:
    verilator_trace_trigger.py [--trace-trigger=STRING] <verilator_bin> <elf> [<elf> ...]

Arguments:
    verilator_bin        Path to the verilator simulation binary
    elfs                 One or more ELF files to pass to verilator with -E

Options:
    --trace-trigger STR  Watch the UART for STR and toggle tracing (SIGUSR1) when found
"""

import argparse
import asyncio
import re
import sys

import serial


def parse_args():
    parser = argparse.ArgumentParser(
        description="Run verilator, streaming its log and UART output. "
                    "Optionally toggle tracing when a trigger string appears on the UART."
    )
    parser.add_argument(
        "--trace-trigger",
        metavar="STRING",
        default=None,
        help="Watch the UART for STRING and send SIGUSR1 to toggle tracing when found",
    )
    parser.add_argument("verilator_bin", help="Path to the verilator simulation binary")
    parser.add_argument("elfs", nargs="+", help="ELF files passed to verilator with -E")
    return parser.parse_args()


async def drain_verilator(proc, uart_path_holder, uart_ready, kill_cmd_holder, kill_ready):
    """Read and print verilator output, capturing UART path and kill command."""
    uart_pattern = re.compile(r"\$\s*screen\s+(\S+)")
    kill_pattern = re.compile(r"\$\s*(kill\s+-USR1\s+\d+)")

    async for line_bytes in proc.stdout:
        line = line_bytes.decode(errors="replace")
        sys.stderr.write(line)

        if not uart_ready.is_set():
            m = uart_pattern.search(line)
            if m:
                uart_path_holder[0] = m.group(1)
                print(f"[verilator] UART device: {uart_path_holder[0]}", file=sys.stderr)
                uart_ready.set()

        if not kill_ready.is_set():
            m = kill_pattern.search(line)
            if m:
                kill_cmd_holder[0] = m.group(1)
                print(f"[verilator] kill cmd: {kill_cmd_holder[0]}", file=sys.stderr)
                kill_ready.set()

    # Unblock any waiters if verilator exits before printing expected lines
    uart_ready.set()
    kill_ready.set()


async def stream_uart(device_path, trigger_string=None):
    """
    Read from the UART device and print its output.
    If trigger_string is given, return when it is found on the UART.
    Otherwise, stream indefinitely until cancelled.
    """
    if trigger_string:
        print(
            f"[uart] Watching '{device_path}' for '{trigger_string}' ...",
            file=sys.stderr,
        )
    else:
        print(f"[uart] Streaming '{device_path}' ...", file=sys.stderr)

    loop = asyncio.get_running_loop()
    with serial.Serial(device_path, timeout=1) as ser:
        while True:
            line_bytes = await loop.run_in_executor(None, ser.readline)
            line = line_bytes.decode(errors="replace")
            if line:
                print(line, end="")
                if trigger_string and trigger_string in line:
                    print("[uart] trigger found", file=sys.stderr)
                    return


async def execute_kill_command(kill_cmd):
    """Execute the captured kill command as an async subprocess."""
    parts = kill_cmd.split()
    print(f"[trace_trigger] Executing: {' '.join(parts)}", file=sys.stderr)
    proc = await asyncio.create_subprocess_exec(*parts)
    await proc.wait()


async def main():
    args = parse_args()

    verilator_cmd = [args.verilator_bin] + [item for elf in args.elfs for item in ["-E", elf]]
    print(f"[verilator] Starting: {' '.join(verilator_cmd)}", file=sys.stderr)

    proc = await asyncio.create_subprocess_exec(
        *verilator_cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.STDOUT,
    )

    uart_path_holder = [None]
    kill_cmd_holder = [None]
    uart_ready = asyncio.Event()
    kill_ready = asyncio.Event()

    drain_task = asyncio.create_task(
        drain_verilator(proc, uart_path_holder, uart_ready, kill_cmd_holder, kill_ready)
    )

    await uart_ready.wait()

    if uart_path_holder[0] is None:
        print("[verilator] warning: no UART device found in log, skipping UART streaming", file=sys.stderr)
        await proc.wait()
        await drain_task
        return

    if args.trace_trigger:
        await kill_ready.wait()
        if kill_cmd_holder[0] is None:
            print("[verilator] warning: no kill command found in log, cannot trigger tracing", file=sys.stderr)
            uart_task = asyncio.create_task(stream_uart(uart_path_holder[0]))
            await proc.wait()
            uart_task.cancel()
        else:
            await stream_uart(uart_path_holder[0], trigger_string=args.trace_trigger)
            await execute_kill_command(kill_cmd_holder[0])
    else:
        uart_task = asyncio.create_task(stream_uart(uart_path_holder[0]))
        await proc.wait()
        uart_task.cancel()

    await drain_task


if __name__ == "__main__":
    asyncio.run(main())
