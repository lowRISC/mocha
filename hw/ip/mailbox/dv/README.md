<!--
Copyright lowRISC and contributors (COSMIC project).
Licensed under the Apache License, Version 2.0, see LICENSE for details.
SPDX-License-Identifier: Apache-2.0
-->

# Mailbox DV document

This document is the block-level verification strategy for the Mocha mailbox.
It describes the testbench architecture, the origin of each component, the stimulus, the coverage model and the checking, and how to run the tests.
The [testplan][testplan section] holds the testpoints and the [vPlan][vplan section] holds the features to verify with their coverage, so neither is restated here.

## Goals

- Verify the mailbox as Mocha instantiates it, through dynamic simulation with a UVM testbench.
- Run the tests of the [testplan][testplan section] towards closing code and functional coverage on the block and its sub-modules.
- Take every expected result from the specification, and report each place where the specification is silent or the RTL disagrees with it.

No formal testbench is planned.

## Current status

This document is the specification of the complete DV environment, not a record of its current state.
Parts of it are not in the tree yet.
The stage reached and its checklist are recorded under [Verification sign-offs][sign-offs] on the Mocha mailbox page.
The stages and their checklists are defined in [stages.md][verification stages].

## Design features

The block is the PULP `axi_lite_mailbox`, vendored with the PULP AXI repository.
Its [specification] and the [Mocha mailbox page][mailbox page], which gives the Mocha parameters and patches, are authoritative.
What follows is the subset that shapes this testbench.

- Two AXI4-Lite subordinate ports expose the same ten registers, each port at its own base address.
  In Mocha, port 0 is reached from the main crossbar at `top_pkg::MailboxBase` and port 1 is the external port at `top_pkg::MailboxExtBaseAddr`.
  The data bus is 64 bits wide, so the registers are 8 bytes apart.
- Two FIFOs of depth `MailboxDepth`, which is 3 in Mocha.
  A word written to MBOXW on one port is read from MBOXR on the other.
- A write to a full FIFO or a read from an empty one answers SLVERR and sets a bit in ERROR, which clears on read.
- STATUS gives each port the EMPTY and FULL flags and the two threshold comparisons.
  WIRQT sets the threshold for the FIFO the port writes and RIRQT for the one it reads.
  A threshold of `MailboxDepth` or more is clamped to `MailboxDepth - 1`.
- IRQS holds sticky interrupt status, cleared by writing 1.
  IRQEN enables each source and IRQP is IRQS AND IRQEN.
  Each port drives one bit of `irq_o`, level-sensitive and active high.
- CTRL flushes either FIFO from either port.
- Both ports share one clock and one asynchronous active-low reset, and `test_i` is tied to 0.

The register logic is hand-written in the RTL.
[`mailbox.hjson`][mailbox.hjson] describes the same registers from the specification, for the Mocha parameters, and only generates the register model.

## Specification gaps

TODO: update this section once [#755] is addressed.

## Out of scope

- The integration of the block in a system: the interconnect and any protocol converters in front of its ports, and the routing of `irq_o`.
- The sub-modules on their own.
  `fifo_v3`, `spill_register` and `addr_decode` resolve to the lowRISC wrappers in `hw/ip/common_cells`, and they are verified here through the mailbox ports.

## Testbench architecture

The environment is plain UVM.
It drives the ports with the [AXI agent] and builds everything else on `uvm_pkg` classes.
The register model still comes from [`ralgen`][ralgen], whose `dv_base_reg` classes extend `uvm_reg`.

### Block diagram

![Mailbox block-level testbench][tb diagram]

Each box carries its origin, with the meaning given in the [component table].

### Verification components

The components come from four sources:

- **Reuse**: taken as it is.
- **Reuse and extend**: a shared component, extended for every environment that uses it.
- **Build**: written for this environment, or for Mocha DV when the location is shared.
- **Generated**: produced at build time from a description in this tree.

| Component | Origin | Location |
| :---- | :---- | :---- |
| `mailbox_base_test` | Build | `tests/` |
| `mailbox_env`, `mailbox_env_cfg`, `mailbox_virtual_sequencer` | Build | `env/` |
| `mailbox_scoreboard`, with its models `mailbox_access` and `mailbox_state` | Build | `env/` |
| `mailbox_reg_predictor`, one per port | Build | `env/` |
| `mailbox_env_cov`, the functional coverage model | Build | `env/` |
| Virtual sequences | Build | `env/seq_lib/` |
| `axi_mgr_agent`, one per port | Reuse and extend | [`hw/ip/dv/axi_agent`][axi agent] |
| `axi_mgr_protocol_sva_if` and `axi_sub_protocol_sva_if`, bound to every `axi_if` | Reuse and extend | `hw/ip/dv/axi_agent/sva` |
| `axi_vip_if`, one per port | Reuse | `hw/ip/dv/axi_agent/axi_vip` |
| `clk_rst_if` and `pins_if` | Reuse | [`common_ifs`][common_ifs] |
| `dv_report_server` and the `dv_utils` macros | Reuse | [`dv_utils`][dv_utils] |
| `csr_excl_item` | Reuse | `dv_base_reg` |
| Register model, `mailbox_ral_pkg` | Generated | `ralgen` from [`mailbox.hjson`][mailbox.hjson] |

### Top level testbench

`tb/tb.sv` instantiates:

- `clk_rst_if`, the single clock and reset, published in `uvm_config_db` as `clk_rst_vif`.
- The DUT `axi_lite_mailbox` as `dut`, with the parameters of the `top_chip_system` instance: `MailboxDepth` from `mailbox_env_pkg`, the `top_pkg` AXI widths and types, and the two `top_pkg` base addresses.
- One `axi_vip_if` per port, in `Manager` mode with `IsLite` set.
  Each publishes its `axi_if` for the agent of that port, `env.m_axi_agent_main` or `env.m_axi_agent_ext`.
  `tb.sv` connects the AXI4-Lite subset of the full AXI request to the DUT, and ties the response ID and USER fields to 0 and RLAST to 1.
- `intr_if`, a `pins_if` on `irq_o`, published as `intr_vif`.

The agent's `sva` core binds the protocol checkers into every `axi_if`, so both ports are checked with no bind file in this tree.

### Environment configuration

The test creates `mailbox_env_cfg`, fills it, and hands it to the environment before `build_phase`.
It holds:

- `clk_rst_vif` and `intr_vif`, from `uvm_config_db`.
- `ral[NumPorts]`, one register block per port at that port's base address, built and locked by `initialize()`.
- `en_cov`, set by `+en_cov=1`, which the DVSim `cov` mode passes.
  The environment builds the coverage model only when it is set.
- `zero_delays`, set by `+zero_delays=1`, which turns every channel delay off.
- `irq_latency_cycles`, the [interrupt latency limit][interrupt output].
- The minimum number of MBOXR words, and of the other checks a test targets, that the scoreboard must see before the test can pass.

### AXI manager agents

Each port has one [`axi_mgr_agent`][axi agent].
`mailbox_env` runs `run_layered_register_vseq()` on both, so the default map of each register block sends its accesses through the register layering sequencer and `axi_reg_adapter` of that port's agent.
On AXI4-Lite the adapter sends full-width transfers with the register's strobes.
Each agent's monitor feeds its port's predictor and the scoreboard.

`m_vsqr` also holds each agent's `axi_mgr_sequencer`.
A vseq sends single transfers on it with `axi_single_write_seq` and `axi_single_read_seq` for the accesses the register model cannot express: partial strobes, addresses with no register, and reads and writes against a register's access type.

Channel timing is random on all five channels of both ports:

- The agent already randomises how long BREADY and RREADY stay low after their valid, through `axi_response_accept_item`.
- The agent is extended with random delays before AWVALID, WVALID and ARVALID, and with W sent ahead of AW.
  The extension lives in the shared agent, so other environments get it too.
- `zero_delays` forces every delay to 0.

### UVM RAL model

`ralgen` generates `mailbox_ral_pkg` from [`mailbox.hjson`][mailbox.hjson] at build time.
The same `mailbox_reg_block` is built twice, as `cfg.ral[PortMain]` and `cfg.ral[PortExt]`.

Auto-prediction is off.
`mailbox_reg_predictor` updates each mirror from that port's monitor, for two reasons:

- `uvm_reg_predictor` updates the mirror whatever the response, so the predictor passes on only accesses answered OKAY.
- The WIRQT and RIRQT clamp applies to the whole written word, which a 2-bit field cannot express, so `pre_predict()` applies it.

STATUS, ERROR, IRQS and IRQP are volatile, so the register model compares them only in `mailbox_csr_hw_reset`.
The scoreboard predicts them and checks every read.

MBOXW, MBOXR and CTRL carry the tag `excl:CsrAllTests:CsrExclAll` in the description.
`ralgen` turns it into a `csr_excl_item` entry on the register block, and the CSR sequences leave those registers out.

### Global types and methods

`mailbox_env_pkg` holds what the testbench and the environment share:

```systemverilog
parameter int unsigned MailboxDepth = 3;
parameter int unsigned NumPorts = 2;

typedef enum int unsigned {
  PortMain = 0,
  PortExt  = 1
} mailbox_port_e;

parameter string PortName [NumPorts] = '{"main", "ext"};

function automatic uvm_reg_data_t mailbox_clamp_threshold(uvm_reg_data_t value);
```

`MailboxDepth` comes from the [Mocha mailbox page][mailbox page], and `tb.sv` passes it to the DUT.

## Stimulus strategy

All stimulus goes through the two AXI agents, as register accesses through each port's register model or as single transfers on the agent's sequencer.
There is no firmware at block level.

### Test sequences

The sequences live in `env/seq_lib`.
`mailbox_base_test` runs the virtual sequence that `+UVM_TEST_SEQ` names on `m_vsqr`, after randomising it.
It also installs `dv_report_server`, which DVSim reads for the verdict, and sets a 10 ms watchdog that `+test_timeout_ns` overrides.

`mailbox_base_vseq` resets the DUT and both register models in `pre_start()`, unless `do_dut_init` is cleared by a vseq that runs it inside another.
It gives the tests helpers that leave every check to the scoreboard:

- `write_mboxw()`, `read_mboxr()`, `read_status()` and `read_error()`.
- `fill()` and `drain()`, which move a number of words through one direction.
- `set_thresholds()`, `set_irqen()` and `ack_irqs()`.
- `flush()`, which writes CTRL.
- `raw_write()` and `raw_read()`, single transfers with any address and strobes.

`mailbox_smoke_vseq` sends 2 to 6 batches of random words, each from a random port and drained by the other before the next, and at least one batch fills the FIFO.
It then writes on both ports at once and drains both at once.
STATUS is read after each write batch, before each MBOXR read, and after each drain.
It never writes a full FIFO or reads an empty one.

`mailbox_csr_base_vseq` picks the registers each CSR test may access, by field access type and by exclusion tag.
The four CSR tests extend it:

- `mailbox_csr_hw_reset_vseq` reads every readable register on both ports straight after reset, volatile fields included.
- `mailbox_csr_rw_vseq` writes each R/W register on both ports and reads it back.
  Directed values come first, shuffled.
  WIRQT and RIRQT get 0, `MailboxDepth - 1`, `MailboxDepth` and a value with reserved bits set, and IRQEN gets 0, all fields set and a value with reserved bits set.
  20 to 50 random writes follow, half of them between 0 and `MailboxDepth`.
- `mailbox_csr_bit_bash_vseq` runs `uvm_reg_single_bit_bash_seq` on each R/W register.
  The volatile IRQS fields are left out and only its reserved bits are bashed.
- `mailbox_csr_aliasing_vseq` writes one R/W register at a time in random order and reads back every readable register on both ports after each write.

The four are built on `uvm_reg` and `uvm_reg_single_bit_bash_seq`, which keeps `csr_utils_pkg` and its global state out of the environment.

Every other testpoint has a vseq of the same name, `mailbox_<testpoint>_vseq`, built from the helpers above.
Three of them have a structure of their own:

- `mailbox_access_errors_vseq`, `mailbox_unmapped_access_vseq` and `mailbox_partial_writes_vseq` use `raw_write()` and `raw_read()`, since the register model cannot produce those accesses.
- `mailbox_stress_vseq` runs randomly chosen functional vseqs on both ports at once, with `do_dut_init` cleared, and random accesses to every register in between.
  It runs once more with `zero_delays`, so back-to-back transfers reach the DUT on every channel.
- `mailbox_stress_with_rand_reset_vseq` starts `mailbox_stress_vseq`, asserts reset at a random clock cycle, and stops it.
  It then checks the reset value of every register as `mailbox_csr_hw_reset_vseq` does, and sends a batch of words each way.

### Test list strategy

The [testplan] is the authority for the list of tests.

Randomised:

- The words, the batch sizes and the writing port.
- WIRQT and RIRQT, including values that clamp and values with reserved bits set, and IRQEN.
- When interrupts are acknowledged and when FIFOs are flushed, relative to the traffic.
- The mix and order of accesses on both ports in the stress tests.
- The delays on all five channels of both ports, and the cycle at which reset hits in `mailbox_stress_with_rand_reset`.

Directed:

- The CSR tests, apart from their register order and values.
- The fill and drain steps that bring a FIFO to full or empty before an error access.
- The address lists of `mailbox_unmapped_access` and the strobe patterns of `mailbox_partial_writes`.

Stage split:

- V1 covers the nominal path and the registers: `mailbox_smoke` and the four CSR tests, with the scoreboard and the assertions on.
- V2 covers every other testpoint, the full scoreboard model with `irq_o`, and functional and code coverage to the vPlan goals.
- V3 closes coverage to 100% with reviewed exclusions, with every seed passing.

## Coverage

The [vPlan][vplan section] is the authority for the coverage expected.
Each vPlan feature links to its evidence: a covergroup or cover property below, a code coverage metric, an assertion, or a test result.
DVSim merges the coverage of a regression and DVPlan back-annotates the results onto the vPlan.

### Functional coverage

`mailbox_env_cov` holds the covergroups, and the scoreboard samples them once it has checked an access.
A covergroup samples observed values, such as the response or the value read, and model values that are the same in every state the scoreboard still keeps.
A model value that differs between those states is not sampled.

| Covergroup | What it samples | vPlan features |
| :---- | :---- | :---- |
| `fifo_cg`, per FIFO | Each MBOXW and MBOXR access: the FIFO level before it, for each access kind and response | `data_transfer`, `fifo_depth`, `write_full`, `read_empty` |
| `status_cg`, per port | Each STATUS read: every flag at 0 and 1, WFIFOL crossed with WIRQT and the write FIFO level, and RFIFOL crossed with RIRQT and the read FIFO level | `status_empty_full`, `status_threshold_flags` |
| `threshold_cg`, per port and register | Each WIRQT and RIRQT write: each value below `MailboxDepth`, `MailboxDepth` and above within the field, and a value with reserved bits set | `threshold_registers` |
| `irqs_cg`, per port | Each IRQS bit setting: its source and whether IRQEN enables it, and each IRQS write: which bits it acknowledges and whether they were set | `threshold_irq_status`, `error_irq_status`, `irq_status_without_enable` |
| `irqp_cg`, per port | Each IRQP value, as IRQS crossed with IRQEN bit by bit | `irq_enable_pending` |
| `irq_pin_cg`, per port | Each change of `irq_o`: its direction and the IRQP bits behind it | `irq_level` |
| `error_cg`, per port | Each ERROR read: none, read error, write error or both, and whether an error access overlapped it | `error_clear_on_read` |
| `flush_cg`, per port | Each CTRL write: the bits written, crossed with the level of each FIFO and with whether accesses were in flight | `flush`, `flush_during_traffic` |
| `access_cg`, per port | Every access: the register or no register, the direction, full or partial strobes, and the response | `access_type_errors`, `unmapped_access`, `partial_writes` |
| `concurrency_cg` | Each OKAY MBOXW and MBOXR access: whether any access was in flight on the other port while it was, and each OKAY MBOXW or MBOXR there that overlapped it and answered first | `concurrent_bidirectional` |
| `reset_cg` | Each reset: whether accesses were in flight and whether either FIFO held words | `reset_during_traffic` |

The protocol checkers carry cover properties on each port: AW before W, W before AW and both in one cycle, each valid held while its ready is low, and back-to-back transfers on each channel.
They answer for `axil_write_handshake` and `axil_read_handshake`, and the assertions of the same interfaces for `axil_protocol`.

The register map, the base address of each port and the reset values are covered by the CSR test results, and the `request_response` scenario by the result of `mailbox_request_response`.

### Code coverage

DVSim collects code coverage with `--cov`, and the `nightly` regression enables it.
The default Xcelium configuration selects `axi_lite_mailbox` and every module below it.
The targets are those of the stages: 90% of each metric at V2 and 100% at V3.

Exclusions sit in `cov/`, listed in `mailbox_sim_cfg.hjson`, and each one carries a written justification and is reviewed.
They cover what the Mocha instance cannot reach, such as `test_i` tied to 0.

## Self-checking strategy

Four mechanisms check the design:

1. The scoreboard checks every access on both ports, its response and any value read, and `irq_o`.
2. The register model checks register values in the CSR tests, through `mirror()` with `UVM_CHECK`.
3. Assertions check the AXI4-Lite protocol on both ports and known values on every output.
4. End-of-test checks catch accesses left unanswered and tests that checked too little.

### Scoreboard

`mailbox_scoreboard` extends `uvm_scoreboard`.
It takes both ends of every access on each port, the request at its AW or AR handshake and the completed transaction, the reset of the main agent, which both ports share, and `irq_o` through `intr_vif`.

`mailbox_state` holds one possible state of the design, from the specification:

- The words in each FIFO, as the IDs of the MBOXW writes that put them there, in order.
- For each port, WIRQT, RIRQT, ERROR, IRQS and IRQEN.
  STATUS and IRQP are derived from these.

The effects it applies:

- MBOXW pushes a word.
  On a full FIFO it answers SLVERR and sets ERROR.WRITE_ERR and IRQS.EIRQ on the writing port.
- MBOXR pops a word.
  On an empty FIFO it answers SLVERR and sets ERROR.READ_ERR and IRQS.EIRQ on the reading port.
- A read of ERROR returns its value and clears it.
- WIRQT and RIRQT take the written value, clamped, and IRQEN takes the written value.
- IRQS.WTIRQ and IRQS.RTIRQ are set whenever the matching STATUS threshold flag is set, and every IRQS bit clears when 1 is written to it.
- A CTRL write empties the FIFOs its bits name.

The response of every access and every value read are checked against the model, with reserved bits read as 0.
Each MBOXR word is compared with the word at the head of its FIFO in the model.

The specification does not say when an access takes effect.
The scoreboard takes each access to take effect once, somewhere between its address handshake and its response.
Two accesses that overlap may take effect in either order.
On one port, reads keep their request order and so do writes, since AXI4-Lite has no IDs.
The scoreboard keeps every model state that agrees with the responses checked so far, and reports a response that no order of the accesses in flight explains.
It checks a response at the clock edge after it, so every request of that cycle is already recorded.

An access whose result depends on an undecided point in [Specification gaps] is reported as an `UNMODELLED` error.
So no test passes on a result the specification has not settled.

On reset the scoreboard drops every pending access and returns the model to its reset state.

### Interrupt output

The scoreboard samples `irq_o` at every clock edge.
Each bit must reach the OR of the predicted IRQP bits of its port within `irq_latency_cycles` of the response of the access that changes them, and must not change at any other time.
The specification gives no latency, so `irq_latency_cycles` is a testbench limit.
A failure of this check is classified from the waves before it is called a design bug.

### End-of-test checks

At the end of the test the scoreboard reports:

- An access still waiting for its response.
- An MBOXR word that matches no write.
- A test that checked fewer MBOXR words, or fewer of the other checks it targets, than its configuration asks for.

### Assertions

- The RTL carries known-value assertions on `irq_o` and on the response signals of both ports, with the B and R payloads gated on their valid.
- `axi_sub_protocol_sva_if` checks the subordinate obligations of the AMBA AXI specification, issue H.c, on each port, in its AXI4-Lite mode.
  BVALID and RVALID stay high until their handshake with their payload steady, a B response only answers a write whose AW and W have both completed, and an R response only answers an outstanding read.
  On AXI4-Lite, RLAST is high and no response is EXOKAY.
  Every valid is low during reset, and the handshake and control signals are known outside it.
- `axi_mgr_protocol_sva_if` checks the manager obligations on the same ports, so a fault in the agent fails as well.

Both run in every test.

## Tools

Versions are pinned in [`tool_data.json`][tool_data.json] at the repository root.

| Tool | Role |
| :---- | :---- |
| Xcelium | Simulator |
| DVSim | Build, run, regressions and coverage reports |
| DVPlan | vPlan authoring and back-annotation of results |

## Building and running tests

Simulations are built and run with [DVSim], from the simulation configuration `mailbox_sim_cfg.hjson`.
DVSim and the simulators are in the Mocha nix shell.
`nix develop` opens it, and this runs a single command in it from the repository root:

```console
nix run .#baremetal -- <command>
```

Run the smoke test:

```console
dvsim hw/ip/mailbox/dv/mailbox_sim_cfg.hjson -i mailbox_smoke
```

Run all the tests, or all of them with coverage:

```console
dvsim hw/ip/mailbox/dv/mailbox_sim_cfg.hjson -i all
dvsim hw/ip/mailbox/dv/mailbox_sim_cfg.hjson -i nightly
```

The Mocha batch configuration [`mocha_sim_cfgs.hjson`][mocha_sim_cfgs.hjson] includes the mailbox, so the same regressions run from it:

```console
dvsim hw/top_chip/dv/mocha_sim_cfgs.hjson --select-cfgs mailbox -i smoke
```

### Regressions

- `smoke`: `mailbox_smoke`.
- `all`: every test, each on the `reseed` count `mailbox_sim_cfg.hjson` gives it.
- `all_once`: every test once.
- `nightly`: the runs of `all`, with coverage.

## File tree

```
hw/ip/mailbox/
  data/                       Register description, testplan and vPlan.
  dv/
    mailbox_sim_cfg.hjson     DVSim simulation configuration.
    mailbox_sim.core          FuseSoC core for the sim target.
    doc/                      Block diagram.
    cov/                      Code coverage exclusions, each with its justification.
    tb/                       Testbench top: DUT, clock and reset, interfaces.
    tests/                    Base test.
    env/                      Environment, configuration, scoreboard and its model, predictors, coverage.
      seq_lib/                Virtual sequences.
```

## Testplan

The [testplan] holds the simulation testpoints and the stage of each.
A testpoint lists its tests once they exist in `mailbox_sim_cfg.hjson`.

## Verification plan

The [vPlan] holds the features to verify, grouped by where each is measured, with the requirement each one traces to.
Each feature links to its evidence: functional coverage, code coverage, assertions, test results, or a manual review where nothing can be measured.
It also gives the stage of each feature.

[testplan section]: #testplan
[vplan section]: #verification-plan
[sign-offs]: ../../../../doc/proj/mailbox.md#verification-sign-offs
[verification stages]: ../../../../doc/proj/stages.md#hardware-ip-block-verification-stages
[specification]: ../../../vendor/pulp_axi/doc/axi_lite_mailbox.md
[mailbox page]: ../../../../doc/proj/mailbox.md
[mailbox.hjson]: ../data/mailbox.hjson
[#755]: https://github.com/lowRISC/mocha/issues/755
[axi agent]: ../../dv/axi_agent/README.md
[ralgen]: ../../../vendor/lowrisc_ip/dv/tools/ralgen/README.md
[tb diagram]: doc/tb.svg
[component table]: #verification-components
[common_ifs]: ../../../vendor/lowrisc_ip/dv/sv/common_ifs/README.md
[dv_utils]: ../../../vendor/lowrisc_ip/dv/sv/dv_utils/README.md
[interrupt output]: #interrupt-output
[specification gaps]: #specification-gaps
[tool_data.json]: ../../../../tool_data.json
[dvsim]: https://github.com/lowRISC/dvsim
[mocha_sim_cfgs.hjson]: ../../../top_chip/dv/mocha_sim_cfgs.hjson
[testplan]: ../data/mailbox_testplan.hjson
[vplan]: ../data/mailbox_vplan.hjson
