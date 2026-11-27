# UART 16550 Hardware IP Block

The UART 16550 IP block is a wrapper around the [OpenTitan UART IP][opentitan-uart], which allows it to be used with the standard 16550 register map.

> [!IMPORTANT]
> The design for this IP is incomplete and the RTL will change significantly. This IP is also not well verified.

## Register functionality

As the OpenTitan UART IP and the [16550 specification][16550-spec] have different feature sets, this wrapper only provides features supported by both implementations. The differences in register functionality are further described in the [register documentation](doc/registers.md).

## Functional differences

Additional functional differences from the [16550 specification][16550-spec] are listed below:

- Receive FIFO size is 64 bytes
- Transmit FIFO size is 32 bytes
- Received characters with framing error or parity error are not pushed into the RCVR FIFO.

## Interrupts

This wrapper provides the same set of interrupt outputs as the OpenTitan UART IP. The following interrupt outputs will however always be inactive as they are never enabled by the wrapper:

- tx_watermark
- tx_done

## Features not yet implemented

- TL-UL host request integrity check, integrity errors will be ignored
- TL-UL host `PutPartialData` opcode, which will behave as `PutFullData`
- TL-UL host request size other than 2, which will be treated as 2
- RACL, all registers will always be accessible

[opentitan-uart]: https://github.com/lowRISC/opentitan/tree/master/hw/ip/uart
[16550-spec]: https://web.archive.org/web/20180826215135/http://www.ti.com/lit/ds/symlink/pc16550d.pdf
