#!/usr/bin/env python3
"""
Run a verilator simulation, streaming verilator log and UART output.
Optionally toggle tracing (SIGUSR1) when a trigger string appears on the UART.

The UART device path is extracted from the verilator log (a line in the
format "$ screen /dev/pts/N").

Usage:
    verilator_trace_trigger.py [--trace-trigger=STRING] [--verilator-bin=PATH] <elf> [<elf> ...]

Arguments:
    elfs                 One or more ELF files to pass to verilator with -E

Options:
    --verilator-bin PATH Path to the verilator simulation binary
                         (default: build/lowrisc_mocha_top_chip_verilator_0/
                          sim-verilator/Vtop_chip_verilator)
    --trace-trigger STR  Watch the UART for STR and toggle tracing (SIGUSR1) when found
"""

import argparse
import asyncio
import re
import sys
from pathlib import Path
from typing import Optional

import serial

_CYAN  = "\033[36m"
_GREEN = "\033[32m"
_DIM   = "\033[2m"
_RESET = "\033[0m"

_DEFAULT_VERILATOR_BIN = str(
    Path(__file__).resolve().parent.parent
    / "build/lowrisc_mocha_top_chip_verilator_0/sim-verilator/Vtop_chip_verilator"
)


def parse_args() -> argparse.Namespace:
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
    parser.add_argument(
        "--verilator-bin",
        default=_DEFAULT_VERILATOR_BIN,
        help=f"Path to the verilator simulation binary (default: {_DEFAULT_VERILATOR_BIN})",
    )
    parser.add_argument("elfs", nargs="+", help="ELF files passed to verilator with -E")
    return parser.parse_args()


async def drain_verilator(
    proc: asyncio.subprocess.Process,
    uart_path_holder: list[Optional[str]],
    uart_ready: asyncio.Event,
    kill_cmd_holder: list[Optional[str]],
    kill_ready: asyncio.Event,
) -> None:
    """Read and print verilator output, capturing UART path and kill command."""
    uart_pattern = re.compile(r"\$\s*screen\s+(\S+)")
    kill_pattern = re.compile(r"\$\s*(kill\s+-USR1\s+\d+)")

    async for line_bytes in proc.stdout:
        line = line_bytes.decode(errors="replace")
        sys.stderr.write(_DIM + line + _RESET)

        if not uart_ready.is_set():
            m = uart_pattern.search(line)
            if m:
                uart_path_holder[0] = m.group(1)
                print(
                    f"{_CYAN}[verilator] UART device: {uart_path_holder[0]}{_RESET}",
                    file=sys.stderr,
                )
                uart_ready.set()

        if not kill_ready.is_set():
            m = kill_pattern.search(line)
            if m:
                kill_cmd_holder[0] = m.group(1)
                print(
                    f"{_CYAN}[verilator] kill cmd: {kill_cmd_holder[0]}{_RESET}",
                    file=sys.stderr,
                )
                kill_ready.set()

    # Unblock any waiters if verilator exits before printing expected lines
    uart_ready.set()
    kill_ready.set()


async def stream_uart(
    device_path: str,
    trigger_string: Optional[str] = None,
    trigger_event: Optional[asyncio.Event] = None,
) -> None:
    """
    Read from the UART device and print its output indefinitely until cancelled.
    If trigger_string is given, set trigger_event when it is found on the UART,
    then continue streaming.
    """
    if trigger_string:
        print(
            f"{_CYAN}[uart] Watching '{device_path}' for '{trigger_string}' ...{_RESET}",
            file=sys.stderr,
        )
    else:
        print(f"{_CYAN}[uart] Streaming '{device_path}' ...{_RESET}", file=sys.stderr)

    loop = asyncio.get_running_loop()
    with serial.Serial(device_path, timeout=1) as ser:
        while True:
            line_bytes = await loop.run_in_executor(None, ser.readline)
            line = line_bytes.decode(errors="replace")
            if line:
                sys.stdout.write(_GREEN + line + _RESET)
                sys.stdout.flush()
                if (
                    trigger_string
                    and trigger_event
                    and not trigger_event.is_set()
                    and trigger_string in line
                ):
                    print(f"{_CYAN}[uart] trigger found{_RESET}", file=sys.stderr)
                    trigger_event.set()


async def main() -> None:
    args = parse_args()

    verilator_cmd = [args.verilator_bin] + [item for elf in args.elfs for item in ["-E", elf]]
    print(f"{_CYAN}[verilator] Starting: {' '.join(verilator_cmd)}{_RESET}", file=sys.stderr)

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
        print(
            f"{_CYAN}[verilator] warning: no UART device found in log, "
            f"skipping UART streaming{_RESET}",
            file=sys.stderr,
        )
        await proc.wait()
        await drain_task
        return

    trigger_event = None
    if args.trace_trigger:
        await kill_ready.wait()
        if kill_cmd_holder[0] is None:
            print(
                f"{_CYAN}[verilator] warning: no kill command found in log, "
                f"cannot trigger tracing{_RESET}",
                file=sys.stderr,
            )
        else:
            trigger_event = asyncio.Event()

    uart_task = asyncio.create_task(
        stream_uart(
            uart_path_holder[0],
            trigger_string=args.trace_trigger,
            trigger_event=trigger_event,
        )
    )

    if trigger_event is not None:
        await trigger_event.wait()
        kill_parts = kill_cmd_holder[0].split()
        print(f"{_CYAN}[trace_trigger] Executing: {' '.join(kill_parts)}{_RESET}", file=sys.stderr)
        kill_proc = await asyncio.create_subprocess_exec(*kill_parts)
        await kill_proc.wait()

    await proc.wait()
    uart_task.cancel()

    await drain_task


if __name__ == "__main__":
    asyncio.run(main())
