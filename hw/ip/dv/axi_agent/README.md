# AXI UVM Agent

The AXI agent drives and monitors the manager side of an AXI4 or AXI4-Lite bus, following the AMBA AXI protocol specification, issue H.c, within the limits listed under [Not supported yet](#not-supported-yet).
`axi_mgr_agent` provides a manager, with transfer sequences and a register layering sequence, so a `uvm_reg` model can issue its accesses over AXI.
It also provides a monitor, a reset monitor and a register adapter, and builds only those when passive.

`axi_if` bundles the five channel interfaces (`aw_if`, `w_if`, `b_if`, `ar_if`, `r_if`) and the shared clock and reset.
The channel interfaces use a max-footprint approach: signals are declared at their widest.
The bus properties are set at run time through `set_*` calls: `set_addr_width`, `set_data_width`, `set_id_width`, `set_user_width`, `set_resp_width`, `set_lite` and `set_drive_x_when_idle`.
The monitor looks only at the configured bits of each signal, the drivers read undriven bits as 0, and the manager decodes BRESP and RRESP from their configured bits alone, so the bits above the configured widths may be left undriven.
BRESP and RRESP are two bits wide by default (A3.4.5); `set_resp_width(0)` describes a bus without them.
`set_if_mode` picks `Manager` when the manager agent drives the bus and `Monitor` when nothing drives it.
The channel interfaces also have a `Subordinate` mode, which drives the subordinate's signals through `sub_cb`.
The agent takes the bus with `set_vif()`, or as `vif` from `uvm_config_db`.

`axi_vip/axi_vip_if.sv` wraps an `axi_if` around a pulp_axi struct port, with `IfMode` and `IsLite` parameters, and publishes it as `vif` with the matching `is_active`.

## Configurations

- AXI4, and AXI4-Lite (`set_lite`) at 32 and 64 bit data widths.
- Data buses of 32 to 1024 bits, addresses of up to 64 bits, and IDs and USER signals up to each channel interface's maximum; `set_user_width()` gives every channel one USER width, and the channel interfaces' own setters give them different ones.
  H.c has a single USER_REQ_WIDTH for AWUSER and ARUSER (A8.3.1), so equal widths are the conformant setting.
- INCR bursts of up to 256 transfers, WRAP and FIXED bursts of up to 16, narrow transfers and unaligned start addresses, with the strobes that the address and size give (A3.4).
- Several transactions in flight, responses out of order across IDs and read data interleaved across IDs, in order within an ID (A5.1).
- OKAY, EXOKAY, SLVERR and DECERR responses.
- Exclusive accesses (A7.2).
- Reset in the middle of traffic.
- Payloads whose VALID is low driven X by default, or random but defined with `set_drive_x_when_idle(0)`.

## Not supported yet

- Atomic transactions (AWATOP, E1.1): `axi_if` has no AWATOP, and `axi_vip_if` drives it as 0 in `Manager` mode.
- AXI5 and ACE signals and extensions: the interfaces do not carry them, and `set_resp_width(3)`, for the three-bit responses of later issues, reports "not supported yet".
- QoS and REGION semantics: AxQOS and AxREGION are driven and monitored only.
- Burst accesses through the register layer, which sends one transfer per register access.
- A functional coverage model.

## Manager

The manager has a driver and a sequencer for each channel, and response routers that hand each B response and R beat to the sequence waiting on its ID.
`get_sequencer()` returns an `axi_mgr_sequencer`, on which `axi_transfer_seq`, `axi_single_read_seq` and `axi_single_write_seq` run.
Randomise one of these to choose the request, call `set_bus_properties()` first so that its address, size, ID and USER fit both the AW and the AR channel, and read `m_requests` and `m_responses` once it has finished.
A sequence can be started again: each start sets `m_requests` and `m_responses` afresh, sends new write data if the sequence made up the last, and sends the current `m_wdata` and `m_wstrb` of `axi_single_write_seq`.
A start with `m_beat_wdata` empty fills `m_beat_wdata`, `m_beat_wstrb` and `m_beat_wuser` with new random beats, whatever the other two held.
Write data and read data in these sequences hold the byte at the beat's address in the least significant byte.
The request items keep to the burst rules, the size, length and alignment restrictions on exclusive accesses (A7.2.4) and the legal AxCACHE values (A4.4).
A7.2.4 also asks for an AxCACHE value that takes an exclusive access to the subordinate monitoring it; that depends on the system, so the integration has to choose it.
AxREGION must not change within a 4KB page (A8.2.1), so the request items and transfer sequences set it to 0 with a soft constraint, which a test with a region map overrides.

Concurrent writes send their W beats in the order of their AW requests (A5.2.2), one burst after another.
Calls to the response routers on one ID are served in the order they were made, a whole burst per call, so concurrent sequences on one ID get their own responses.
The drivers decide each handshake from VALID and READY as sampled at the same clock edge (A3.2.1), so an item that arrives between edges takes exactly one handshake.

`run_layered_register_vseq()` starts the register layer, whose sequencer `get_register_layering_sequencer()` returns, with `get_reg_adapter()` as its adapter.
It sends each access as one transfer whose AxSIZE container holds every byte of the access, from the register's address to the last byte of the fields written, with data and strobes on those bytes' lanes (A3.4.1, A3.4.4).
An access that needs more than the data bus is reported as an error and returns `UVM_NOT_OK`.
It can give every access one fixed AxPROT value.
On AXI4-Lite it sends full-width transfers with the register's strobes (B1.1).

The manager drivers answer every item at once, unsent, while reset is asserted.
A sequence that can run into a reset must wait for reset to end itself.

## Analysis ports

The monitor publishes on `m_request_port`, `m_response_port` and `m_transaction_port`, and the agent forwards them on ports of the same names.
A request goes out on `m_request_port` at its AW or AR handshake.
`m_response_port` carries the transaction so far at each B handshake and each R beat.
`m_transaction_port` carries each completed transaction, write or read.
A transaction that is still in flight when reset is asserted is dropped.
The monitor counts a handshake only when VALID and READY are both 1, and reports X only on the byte lanes that carry data: the strobed lanes of a W beat, and the lanes of an R beat answered OKAY or EXOKAY.

## Register adapter

The agent exposes an `axi_reg_adapter` through `get_reg_adapter()`, in passive mode too.
Its `bus2reg()` method converts register layer items and completed transactions published by the monitor, so it can be connected to a `uvm_reg_predictor`.
For a monitored transaction it reports only the bytes that the first beat carries, from its address to the end of its AxSIZE container (A3.4.1).
It reports a burst or an error response with status `UVM_NOT_OK`.
`uvm_reg_predictor` updates the mirror whatever the status says, so a testbench where error responses happen needs a filter between the monitor and the predictor that passes only `UVM_IS_OK` transactions.

An exclusive write answered OKAY by a subordinate that supports exclusive accesses has failed and left memory unchanged (A7.2.3, A7.2.5).
Call `set_exclusive_support(1)` on the adapter that feeds the predictor when the subordinate supports them, and the adapter reports such a write as `UVM_NOT_OK`.
