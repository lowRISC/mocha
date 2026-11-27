# UART 16550 registers

All standard 16550 registers are implemented and accessible at the least significant byte of consecutive 4-byte words. Writes to the more significant 3 bytes are ignored and reads from these 3 bytes return 0.
The register map has a size of 32 bytes and wraps every 32 bytes.
Accesses with a non-zero `a_address[1:0]` return an error.

The difference in functionality between the [16550 specification][16550-spec] and the UART 16550 wrapper is provided in the table below.

| Register | Address offset (bytes) | Access | Difference from the specification |
|-|-|-|-|
| RBR | 0x0 (DLAB=0) | RO | Reads from an empty RCVR FIFO returns 0. |
| THR | 0x0 (DLAB=0) | WO | Writes to a full XMIT FIFO are dropped. |
| IER | 0x4 (DLAB=0) | RW | Values written to EDSSI are kept, but will have no other effect as MODEM status interrupts are never raised. |
| IIR | 0x8 | RO | Received data available indicated by `IIR[3:1] == 0b010` has a higher priority than receive FIFO timeout indicated by `IIR[3:1] == 0b110`. THRE interrupt will not be cleared by reading IIR. |
| FCR | 0x8 | WO | 16450 mode is not supported. Values written to FIFO enable are kept, but will have no other effect as the OpenTitan UART always uses a FIFO. Changing FIFO enable does not clear the FIFOs. All bits of FCR are writable regardless of the value of FIFO enable. Writes to bits 3-5 have no effect. Writing `0b11` to the RCVR FIFO trigger level will set a trigger level of 16 bytes. |
| LCR | 0xC | RW | WLS writes are ignored and reads return `0b11` to indicate 8-bit word length. STB writes are ignored and reads return `0b0` to indicate 1 stop bit. EPS resets to `0b1` to indicate it is enabled by default. Writes to stick parity are ignored and reads return `0b0` to indicate that stick parity is always disabled. |
| MCR | 0x10 | RW | Values written to DTR, RTS and OUT are kept but have no effect on external pins. |
| LSR | 0x14 | RO | Break interrupt is indicated when the Rx pin has been continuously low for 1 bit time less than 2 character times. The first all-zero character of a break sets FE. PE, FE and BI are indicated on reception, with `LSR[7]` being the or reduction of these bits. Writes are ignored and do not return an error. |
| MSR | 0x18 | RO | Reads to DCTS, DDSR, TERI and DDCD always return 0. Reads to CTS, DSR, RI and DCD return 0 when loopback is disabled. Writes are ignored and do not return an error. |
| SCR | 0x1C | RW | - |
| DLL | 0x0 (DLAB=1) | RW | Values written are kept, but will always set CTRL.NCO to 20972, corresponding to 1 Mbaud at 50 MHz clock. One write to DLL/DLM is needed to enable Tx and Rx. |
| DLM | 0x4 (DLAB=1) | RW | Same as DLL. |

[16550-spec]: https://web.archive.org/web/20180826215135/http://www.ti.com/lit/ds/symlink/pc16550d.pdf
