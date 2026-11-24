# AXI UVM Agent

The AXI agents drive and monitor either side of an AXI4 or AXI4-Lite bus, following the AMBA AXI protocol specification, issue H.c, within the limits listed under [Not supported yet](#not-supported-yet) and [Not checked](#not-checked).
`axi_agent` observes a bus: it builds a monitor, a reset monitor and a register adapter.
`axi_mgr_agent` extends it to drive the bus as a manager, with transfer sequences and a register layering sequence, so a `uvm_reg` model can issue its accesses over AXI.
`axi_sub_agent` extends it to answer the bus as a memory-backed subordinate.

`axi_if` bundles the five channel interfaces (`aw_if`, `w_if`, `b_if`, `ar_if`, `r_if`) and the shared clock and reset.
The channel interfaces use a max-footprint approach: signals are declared at their widest.
The bus properties are set at run time through `set_*` calls: `set_addr_width`, `set_data_width`, `set_id_width`, `set_user_width`, `set_lite` and `set_drive_x_when_idle`.
The monitor, the protocol assertions and the drivers look only at the configured bits of each ID, address, WSTRB and USER signal, so the bits above the configured widths may be left undriven or take any value.
BRESP and RRESP are two bits wide (A3.4.5).
`set_if_mode` picks `Manager` when `axi_mgr_agent` drives the bus, `Subordinate` when `axi_sub_agent` drives it and `Monitor` when nothing drives it.
An agent drives the bus only when the interface is in its mode, and observes it otherwise.
The agents take the bus with `set_vif()`, or as `vif` from `uvm_config_db`.

`axi_vip/axi_vip_if.sv` wraps an `axi_if` around a pulp_axi struct port, with `IfMode` and `IsLite` parameters, and publishes it as `vif`.

## Configurations

- AXI4, and AXI4-Lite (`set_lite`) at 32 and 64 bit data widths.
- Data buses of 32 to 1024 bits, addresses of up to 64 bits, and IDs and USER signals up to each channel interface's maximum; `set_user_width()` gives every channel one USER width, and the channel interfaces' own setters give them different ones.
  H.c has a single USER_REQ_WIDTH for AWUSER and ARUSER (A8.3.1), so equal widths are the conformant setting.
- INCR bursts of up to 256 transfers, WRAP and FIXED bursts of up to 16, narrow transfers and unaligned start addresses, with the strobes that the address and size give (A3.4).
- Several transactions in flight on each side, responses out of order across IDs and read data interleaved across IDs, in order within an ID (A5.1).
- OKAY, EXOKAY, SLVERR and DECERR responses.
- Exclusive accesses, with an exclusive access monitor per ID in the subordinate (A7.2).
- Reset in the middle of traffic.
- Payloads whose VALID is low driven X by default, or random but defined with `set_drive_x_when_idle(0)`.

## Not supported yet

- Atomic transactions (AWATOP, E1.1): `axi_if` has no AWATOP.
  `axi_vip_if` drives it as 0 in `Manager` mode and reports an error for an AW request with a nonzero AWATOP in `Subordinate` mode.
- AXI5 and ACE signals and extensions, including the three-bit responses of later issues: the interfaces do not carry them.
- QoS and REGION semantics: AxQOS and AxREGION are driven and monitored only, and the subordinate uses AxREGION only to match an exclusive write with its read.
- Burst accesses through the register layer, which sends one transfer per register access.
- A functional coverage model.

## Manager

The manager has a driver and a sequencer for each channel, and response routers that hand each B response and R beat to the sequence waiting on its ID.
`get_sequencer()` returns an `axi_mgr_sequencer`, on which `axi_transfer_seq`, `axi_single_read_seq` and `axi_single_write_seq` run.
Randomise one of these with constraints on `m_req` to choose the request, call `set_bus_properties()` first so that its address, size, ID and USER fit both the AW and the AR channel, and read `m_requests` and `m_responses` once it has finished.
A sequence can be started again: each start sets `m_requests` and `m_responses` afresh, sends new write data if the sequence made up the last, and sends the current `m_wdata` and `m_wstrb` of `axi_single_write_seq`.
A start with `m_beat_wdata` empty fills `m_beat_wdata`, `m_beat_wstrb` and `m_beat_wuser` with new random beats, whatever the other two held.
Write data and read data in these sequences hold the byte at the beat's address in the least significant byte.
The request items keep to the burst rules, the size, length and alignment restrictions on exclusive accesses (A7.2.4) and the legal AxCACHE values (A4.4).
A7.2.4 also asks for an AxCACHE value that takes an exclusive access to the subordinate monitoring it.
That depends on the system, so the integration has to choose it.
AxREGION must not change within a 4KB page (A8.2.1), so the request items set it to 0 with a soft constraint, which a test with a region map overrides.

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
An item that arrives once reset is released waits for a rising edge that samples ARESETn high before its VALID rises (A3.1.2).

## Subordinate

The subordinate accepts requests on AW, W and AR, answers on B and R, and keeps its data in the `m_mem` of its `axi_sub_agent_cfg`.
Give each agent its configuration with `set_cfg()`, or as `cfg` from `uvm_config_db`.
The agent creates a configuration when it gets none, and a memory when the configuration has none.
It needs no sequence: when none runs, every transaction gets the response that `axi_sub_agent_cfg` gives it, with a latency of `m_default_latency` cycles.
`axi_sub_rsp_seq` on `get_sequencer()` picks a latency, an error and USER values for each transaction, until `stop()` is called.
Its items go to transactions in the order the subordinate accepts them, AW or AR, with the write first when both are accepted at one edge.
A transaction can be answered once its AW and last W handshakes, or its AR handshake, are done.
With a latency of L cycles, its first BVALID or RVALID is sampled L + 1 edges after that at the earliest, so a latency of 0 can answer at the first edge that H.c A3.3.1 allows.
The response comes later if the channel is busy or another transaction goes first: an earlier response still waiting for READY, a read burst in progress without `m_read_interleave`, the idle gap after a read beat, an older transaction that must be answered first (the same ID, or any ID without `m_out_of_order`), or another answerable transaction picked first.
A transaction alone on its channel gets exactly L + 1 edges.

The settings in `axi_sub_agent_cfg`:

- `m_default_byte` is what a byte never written reads as.
- `m_err_addr_valid`, `m_err_addr` and `m_err_addr_mask` select addresses that are answered with `m_err_resp`, SLVERR or DECERR.
- `m_aw_ready`, `m_w_ready` and `m_ar_ready` set READY before VALID, the delay to READY after VALID, and so back-to-back transfers.
- `m_max_outstanding_writes` and `m_max_outstanding_reads` limit the transactions in flight.
  A request that waits at the limit still gets READY no sooner than its delay after VALID.
- `m_out_of_order` lets transactions with different IDs complete in any order, and `m_read_interleave` lets their read data interleave.
  Transactions with the same ID always complete in order.
- `m_exclusive_support` adds an exclusive access monitor per ID.
  An exclusive write gets EXOKAY only when it matches the exclusive read on that ID in address, size, length, burst, cache, protection and region, and no other write has touched those bytes since the subordinate accepted the read.
  The subordinate orders a read at its AR handshake and a write at the later of its AW and last W handshakes.
  A write that updates the read's bytes after its AR handshake, even while the read waits for its data, therefore fails the next matching exclusive write.
  H.c A6.1 also allows a subordinate to order that write before the read, and the exclusive write to succeed.
  A later exclusive read on the ID takes the monitor over (A7.2.1).
  If that read is answered with an error, the monitor for the ID holds nothing.
- `m_lite_strb_policy` says what an AXI4-Lite subordinate does with WSTRB.
- `m_zero_inactive_lanes` zeroes the read data lanes outside a transfer.

A write answered with an error does not change memory.
A reset drops every transaction in flight.

`m_accept_port` publishes each transaction when the subordinate accepts it, with the response policy it was given, so a scoreboard can predict the response from the policy.

### Memory model

The subordinate reads and writes `m_mem` one byte at a time through the virtual methods of `mem_model`: `addr_is_mapped`, `read_byte` and `write_byte`.
A byte for which `addr_is_mapped` returns 0 reads as `m_default_byte`.
The base model maps the bytes that have been written, so a memory with a fixed map and initial contents is a class that overrides these three methods.
The change to `mem_model` is carried as a patch in `hw/vendor/patches/lowrisc_ip/dv_sv`.

## Analysis ports

The monitor publishes on `m_request_port`, `m_response_port` and `m_transaction_port`, and `axi_agent` forwards them on ports of the same names.
A request goes out on `m_request_port` at its AW or AR handshake.
`m_response_port` carries the transaction so far at each B handshake and each R beat.
`m_transaction_port` carries each completed transaction, write or read.
A transaction that is still in flight when reset is asserted is dropped.
The monitor counts a handshake only when VALID and READY are both 1, and reports X only on the byte lanes that carry data: the strobed lanes of a W beat, and the lanes of an R beat answered OKAY or EXOKAY.

## Register adapter

Every agent exposes an `axi_reg_adapter` through `get_reg_adapter()`, in `Monitor` mode too.
Its `bus2reg()` method converts register layer items and completed transactions published by the monitor, so it can be connected to a `uvm_reg_predictor`.
For a monitored transaction it reports only the bytes that the first beat carries, from its address to the end of its AxSIZE container (A3.4.1).
It reports a burst or an error response with status `UVM_NOT_OK`.
`uvm_reg_predictor` updates the mirror whatever the status says, so a testbench where error responses happen needs a filter between the monitor and the predictor that passes only `UVM_IS_OK` transactions.
`dv/env/axi_agent_reg_ok_filter.svh` is such a filter.

An exclusive write answered OKAY by a subordinate that supports exclusive accesses has failed and left memory unchanged (A7.2.3, A7.2.5).
Call `set_exclusive_support(1)` on the adapter that feeds the predictor when the subordinate supports them, and the adapter reports such a write as `UVM_NOT_OK`.
`axi_sub_agent` does this for its own adapter in `build_phase`, from `m_exclusive_support` in its configuration.

## Protocol assertions

`sva/axi_mgr_protocol_sva_if.sv` checks what a manager must do and `sva/axi_sub_protocol_sva_if.sv` what a subordinate must do.
`sva/axi_mgr_protocol_bind.sv` and `sva/axi_sub_protocol_bind.sv` bind them into every `axi_if`.
Elaborate both bind modules as top-level modules, through `sim_tops` or the `design` statement of a configuration as `hw/top_chip/dv/tb/tb_cfg.sv` does, and depend on `lowrisc:mocha_dv:axi_agent_sva`.
They take the bus widths and the AXI4-Lite property from the `axi_if` they are bound into, and look only at the configured bits of each signal.
Their settings are `axi_if` functions too, with one setting for the checks on the manager's outputs and one for those on the subordinate's:

- `set_mgr_disable_sva` and `set_sub_disable_sva` turn the checks off, for a negative test.
- `set_mgr_max_ready_wait` and `set_sub_max_ready_wait` bound how many edges a VALID may wait for that side's READY, so a handshake after exactly that many passes.
  The default, 0, leaves it unbounded.
- `set_mgr_max_output_delay_ps` and `set_sub_max_output_delay_ps` set how long after a rising edge that side's outputs may change, for a model that drives them after the edge.
  The default, 0, allows a change only in the time step of the edge.
- `set_max_reset_release_delay_ps` does the same for ARESETn.

They check:

- VALID held until its handshake, and the payload stable while it waits, on the byte lanes that carry data (A3.2.1).
- VALID low at every edge of a reset and at the first edge after it (A3.1.2).
- Outputs that change, and ARESETn that rises, only in the time step of a rising edge or within the configured delay after it (A3.1.1, A3.1.2).
  Changes while ARESETn is low are not checked.
- VALID known, READY known while its VALID is high, and while VALID is high the request's ID, address, length, size, burst, lock and cache, WSTRB and WLAST, and the response's ID, xRESP and RLAST known.
- Legal requests: burst rules, legal AxCACHE and the exclusive access restrictions, and AXI4-Lite single transfers (A3.4.1, A4.4, A7.2.4, B1.1).
- WSTRB only on the byte lanes of each beat, and WLAST and RLAST on the last beat only, also on a beat still waiting for READY (A3.4.4, A3.2.2).
- No exclusive write on an ID while an exclusive read on that ID is open, counting a read accepted at the edge where the write's AW appears and a write whose W data comes before its AW (A7.2.2).
- The same AxREGION for every request to a 4KB page on each channel (A8.2.1).
- B only for a write whose data is complete, R only for an outstanding read with that ID (A3.3.1).
- EXOKAY only for an exclusive access, also on a response still waiting for READY, no mix of OKAY and EXOKAY in one read, and no EXOKAY on AXI4-Lite (A7.2.5, B1.1.1).
- Read data known on the byte lanes of a beat that succeeded.

### Not checked

- Combinatorial paths from inputs to outputs (A3.1.1), which a simulation checker cannot see.
- Whether AxPROT, AxQOS, AxREGION and the USER signals are known.
- Which of several same-ID requests a response belongs to: the assertions pair responses with requests in order within an ID (A5.1), and only a check of the data, such as the self-test's scoreboard, sees a subordinate that answers them out of order.
- Whether AxCACHE takes an exclusive access to the subordinate monitoring it (A7.2.4).

## Self-test

`dv/` checks the manager and subordinate agents against each other, and each of them against pulp_axi models and RTL, with the protocol assertions on every interface.
The scoreboard compares what each sequence got back with what both monitors saw, predicts responses from the policy that the subordinate published, checks read data against a reference memory and compares the subordinate's memory with it at the end of the test.
A link can turn response or read data prediction off, for a pulp_axi model whose responses are random and for the pulp_axi manager's mixed traffic.
Each read keeps the read data setting in force when the subordinate end saw its request, so a read from the mixed traffic that ends after prediction is turned back on is not checked.
Read data prediction assumes that no write to the same bytes is in flight while a read is, since H.c does not order them (A6.1).
The sequences reserve the bytes of each transfer to keep to that.
An exclusive write's response is predicted exactly, unless a write to the exclusive read's bytes was still in flight when the subordinate accepted the read.
Then OKAY and EXOKAY are both accepted (A6.1).
An OKAY there means that write went first, so the monitor holds nothing until the next exclusive read, and later matching writes must get OKAY (A7.2.3).
It fails the test on a transaction that one end saw and the other did not, on a read that never completed, on a W burst that by the end of the test has no AW request or no WLAST on any bus of the link (A3.3), and when a test did less than it needs, for example too few reordered responses or back-to-back transfers.
Through `axi_to_axi_lite`, it pairs each AXI4-Lite transfer with its beat by address, and checks that each write burst gets the first error response of its AXI4-Lite writes (B1.3.1).
A write beat with no strobes may have no AXI4-Lite write, since a bridge may suppress it (B1.1.3): once a clock edge has passed since the burst's B, the scoreboard checks the burst without it.
In `axi_agent_pulp_mgr_incr`, pulp_axi's own `axi_scoreboard` checks the read data of the run that has no writes, since it models INCR bursts only and drops a byte's old value at the write's B.
This needs the vendor patch `hw/vendor/patches/pulp_axi/0007_Print_axi_scoreboard_expected_data_queue.patch`.
On the side that a pulp_axi model drives, `tb.sv` sets the output delay of the protocol assertions to the model's 2 ns application delay.

`+axi_link` picks the link under test and `+axi_data_width`, `+axi_id_width`, `+axi_addr_width`, `+axi_user_width` and `+axi_lite` the bus between the two agents.
Run it with:

```console
dvsim hw/ip/dv/axi_agent/dv/axi_agent_sim_cfg.hjson -i all -t xcelium
```

The tests are listed in `data/axi_agent_testplan.hjson`.
Each feature, the tests that exercise it and the checks that cover it:

| Feature | Tests | Checks |
| --- | --- | --- |
| Bursts, sizes, strobes and widths | `axi_agent_smoke`, `axi_agent_wide_bus`, `axi_agent_widest_bus`, `axi_agent_narrow_id`, `axi_agent_narrow_addr`, `axi_agent_narrow_pins`, `axi_agent_narrow_pins_ones`, `axi_agent_top_addr` | request legality, strobe and last-beat assertions, beat counts against AxLEN, scoreboard data and memory compares |
| Undriven or high bits above the configured ID, address, WSTRB and USER widths | `axi_agent_narrow_pins`, `axi_agent_narrow_pins_ones` | the monitors' X checks, the knownness and stability assertions, scoreboard compares, ID ordering in both agents |
| INCR bursts of more than 16 beats, up to 256 | the bus width tests above but `axi_agent_top_addr`, `axi_agent_pulp_mgr_incr` | beat counts against AxLEN, minimum counts of bursts longer than 16 beats and of 256 beats |
| Transfer sequences randomised with only `set_bus_properties()` | the bus width tests above | the request drivers' width checks with ARUSER one bit narrower than AWUSER, and an address past the top of the bus rejected by the constraints |
| Transfer sequences started again | the bus width tests above but `axi_agent_top_addr`, `axi_agent_reset` | new data read back after each start, one request and its own responses per start, one data, strobe and WUSER entry per beat after a start with only `m_beat_wdata` cleared, `has_full_transaction()` after a start cut by reset, the second data of a listed W data sequence started twice in memory |
| Ordering and interleaving | `axi_agent_out_of_order` | B and R ordering assertions, end-to-end compares per ID |
| Handshakes and backpressure | `axi_agent_backpressure`, `axi_agent_off_edge`, `axi_agent_x_idle` | VALID, stability and output timing assertions, handshake counts per transfer, the READY-wait bounds at exactly the stalls made on all five channels, the READY delay of AW and AR at an outstanding limit of one |
| Responses and error injection | `axi_agent_errors`, `axi_agent_rsp_order` | response prediction from the published policy, the first BVALID and RVALID at latencies 0, 1, 2 and 5 |
| Memory models | `axi_agent_mapped_mem` | read data and memory compares |
| AXI4-Lite | `axi_agent_lite`, `axi_agent_lite_32` | AXI4-Lite assertions, strobe policy prediction |
| Exclusive accesses | `axi_agent_exclusive` | exclusive assertions, EXOKAY prediction in the scoreboard, including a write made while the exclusive read waits for its data, and two exclusive writes after a write whose data came after the read was accepted |
| Reset | `axi_agent_reset`, `axi_agent_top_addr` | reset assertions, no response from before a reset, no response from a reused B or R accept sequence whose second start is cut by reset, a write waiting on the bytes of a write cut by reset sent after reset release and completed, a write and a read started as reset is released held to the next edge and completed, no transfer sent during reset, no AW, W or AR VALID rising before an edge has sampled the release of a half-period reset |
| Register layer | `axi_agent_reg_layer`, `axi_agent_reg_layer_lite`, `axi_agent_reg_layer_lite_32`, `axi_agent_reg_predictor` | mirror checks, fixed AxPROT, failed exclusive writes kept out of the mirror, a two-byte access at an odd address, the adapter on unaligned transfers, register reads with no ARUSER while AWUSER keeps its width |
| pulp_axi models and RTL | `axi_agent_pulp_mgr`, `axi_agent_pulp_mgr_incr`, `axi_agent_pulp_lite_mgr`, `axi_agent_sim_mem`, `axi_agent_rand_slave`, `axi_agent_lite_regs`, `axi_agent_lite_bridge`, `axi_agent_lite_to_axi`, `axi_agent_xbar` | the assertions and scoreboard checks above at both ends of the link, the bridge's combined responses, and pulp_axi's `axi_scoreboard` as described above. `dv/env/axi_agent_link_cfg.svh` lists what a link leaves out to avoid a known pulp_axi defect: unaligned FIXED bursts on `sim_mem`, WRAP bursts and overlapping writes on `rand_slave`, and WRAP bursts and DECERR on `lite_bridge` |

The `axi_agent_pulp_repro_*` tests reproduce places where a pulp_axi model departs from H.c.
They fail while the model has its defect, so they are not in the `all` regression.
Run one by name with `-i`.
