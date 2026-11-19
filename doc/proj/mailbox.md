# Mailbox

The Mailbox is vendored from the PULP platform [`axi` repository][pulp axi] at revision [`a256a3b`][pulp hash].
The documentation for the hardware IP block is located [in the vendored HW directory tree][block doc].
The Mailbox connects two AXI4-Lite subordinate ports back to back over a pair of FIFOs, so data written on one port is read from the other, and raises a per-port interrupt on FIFO fill level or on an error.
Only the main-port interrupt is consumed in Mocha: it reaches the PLIC as interrupt 11, while the external-port interrupt is brought out of the chip as `mailbox_ext_irq_o` and left unconnected at the Genesys 2 top.
Mocha instantiates it in [`top_chip_system.sv`][instantiation] with a `MailboxDepth` of 3, one port reached from the main crossbar and the other brought out of the chip as an external AXI port, each behind an `axi_to_axi_lite` converter.
The depth is final for D1; the `TODO: Tune me` comment at the instantiation is a note for later tuning, not an open design decision.
The block's RTL carries exactly one Mocha delta. [`0006_Add_Mailbox_Output_Assertions.patch`][assert patch] adds the output known assertions to `axi_lite_mailbox.sv` and `lowrisc:prim:assert` to `axi.core`.
[`0001_Primitives_from_lowRISC_used.patch`][prim patch] leaves `axi_lite_mailbox.sv` unmodified; it redirects the `common_cells` dependency in `axi.core` to the lowRISC wrappers, so the mailbox's `fifo_v3`, `spill_register` and `addr_decode` resolve to `hw/ip/common_cells`, and it removes the `benchs` fileset.
Upstream's own mailbox testbench, `test/tb_axi_lite_mailbox.sv`, is still in the tree but no fileset compiles it, and the `axi.core` `sim_lite_mailbox` target still references the removed fileset.

The rest of this document contains the design checklist for the Mailbox hardware IP block for the CHERI Mocha top.
For more details on the stages and the current state for each block, please refer to the [stages documentation][stages].

## Design sign-offs

### D1

The Mailbox used for D1 sign-off is the one at the vendored revision above.
The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].
This sign-off is based on commit [`b6edc2a`][d1-commit].

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | [Mailbox specification][block doc], covering the parameters, ports, register map and interrupt behaviour.
| Documentation | CSR_DEFINED                | Done   | The registers are defined in the [register address mapping][registers].
| RTL           | CLKRST_CONNECTED           | Done   | Modules containing submodules checked: `axi_lite_mailbox` and `axi_lite_mailbox_slave`, both in `axi_lite_mailbox.sv`, which also declares the unused `axi_lite_mailbox_intf` wrapper, and below them `fifo_v3` and `prim_fifo_sync`. `spill_register` and `prim_fifo_sync_cnt` take a clock and reset and instantiate nothing further in this configuration. `addr_decode` has neither and is confirmed to be purely combinational.
| RTL           | IP_TOP                     | Done   | This module is defined in `axi_lite_mailbox.sv`. It has no core file of its own; it is compiled as part of the vendored `axi.core`.
| RTL           | IP_INSTANTIABLE            | Done   | It is instantiated in top chip system.
| RTL           | PHYSICAL_MACROS_DEFINED_80 | Done   | No memory macros or analogue components. The two mailbox FIFOs are flop-based `fifo_v3` instances.
| RTL           | FUNC_IMPLEMENTED           | Done   | All functionality already implemented.
| RTL           | ASSERT_KNOWN_ADDED         | Done   | Output assertions are [here][output asserts], added by [`0006_Add_Mailbox_Output_Assertions.patch`][assert patch]. They cover the interrupt and subordinate response signals, with the B and R payloads gated on their valid.
| Code Quality  | LINT_SETUP                 | Done   | Verilator lint target with `-Wall` in `top_chip_system.core`. Nine unoptimisable-flat and two width-expansion warnings in the block are suppressed by the PULP AXI waivers in [top_chip_system.vlt][lint waivers]. They will be fixed in [issue #739][waivers issue].

### D2

*Checklist to be defined - see [stages.md][design stages].*

### D3

*Checklist to be defined - see [stages.md][design stages].*

## Verification sign-offs

### V1

All checklist items refer to the [V1 verification sign-off checklist][V1 checklist].
This sign-off is based on commit [`443dba6`][v1-commit].

| Type          | Item                               | Status | Note/Collaterals |
|---------------|------------------------------------|--------|------------------|
| Documentation | DV_DOC_DRAFT_COMPLETED             | Done   | [Mailbox DV document][] describes the goals, testbench architecture, stimulus, coverage, and checking strategy |
| Documentation | TESTPLAN_COMPLETED                 | Done   | [Mailbox testplan][] defines the V1 smoke and CSR testpoints and post-V1 FIFO full and empty, error, threshold, interrupt, request and response, flush, access error, unmapped access, partial write and stress testpoints |
| Testbench     | TB_TOP_CREATED                     | Done   | [tb.sv][] instantiates the clock and reset, one AXI4-Lite interface per port and the interrupt interface along with the Mailbox DUT, with the parameters of the Mocha instance |
| Testbench     | PRELIMINARY_ASSERTION_CHECKS_ADDED | Done   | The AXI agent binds the manager and subordinate protocol assertions into the interface of each port; the Mailbox RTL checks that outputs are known after reset |
| Integration   | PRE_VERIFIED_SUB_MODULES_V1        | Waived | The submodules `fifo_v3`, `spill_register` and `addr_decode` resolve to the lowRISC wrappers in `hw/ip/common_cells`. They are covered through the Mailbox ports, so none carries an independent V1 sign-off |
| Review        | DESIGN_SPEC_REVIEWED               | Done   | The [Mailbox specification][block doc] was reviewed against the Mocha instantiation for this sign-off. It describes the FIFOs, registers, thresholds and interrupts the V1 tests rely on; the contradictions and gaps it leaves for access type errors, partial writes and unmapped addresses are tracked in [issue #755][spec issue] and are out of V1 scope |
| Review        | TESTPLAN_REVIEWED                  | Done   | The [Mailbox testplan][] was reviewed for this sign-off. Its V1 testpoints, `mailbox_smoke` and the four CSR testpoints, apply to both ports of the Mocha instance; the post-V1 testpoints have no tests yet |
| Review        | STD_TEST_CATEGORIES_PLANNED        | Done   | Error scenarios and stress tests are covered in the [Mailbox testplan][]; the Mailbox has no security countermeasures; debug, power and performance are N/A |
| Simulation    | SIM_TB_ENV_CREATED                 | Done   | UVM environment with an AXI manager agent and register predictor per port and a scoreboard |
| Tests         | SIM_SMOKE_TEST_PASSING             | Done   | All V1 testpoints (`mailbox_smoke` and the four CSR tests): 25/25 passed, 5 seeds each, with Xcelium on November 25, 2026 at commit `443dba6` |
| Regression    | SIM_SMOKE_REGRESSION_SETUP         | Done   | `smoke` regression in `mailbox_sim_cfg.hjson` selects `mailbox_smoke`; the aggregate Mocha config imports the Mailbox simulation config |
| Regression    | SIM_NIGHTLY_REGRESSION_SETUP       | Done   | The Mailbox is included in `mocha_sim_cfgs.hjson`; results are published on the [COSMIC reports dashboard][] |
| Coverage      | SIM_COVERAGE_MODEL_ADDED           | Done   | Functional coverage is in [`mailbox_env_cov.sv`][cov model] |
| Tests         | FPV_MAIN_ASSERTIONS_PROVEN         | N/A    | This V1 sign-off uses simulation |
| Regression    | FPV_REGRESSION_SETUP               | N/A    | No Mailbox FPV regression is configured in Mocha |

### V2

*Checklist to be defined - see [stages.md][verification stages].*

### V3

*Checklist to be defined - see [stages.md][verification stages].*

[block doc]: ../../hw/vendor/pulp_axi/doc/axi_lite_mailbox.md
[registers]: ../../hw/vendor/pulp_axi/doc/axi_lite_mailbox.md#register-address-mapping
[stages]: stages.md
[design stages]: stages.md#hardware-ip-block-design-stages
[verification stages]: stages.md#hardware-ip-block-verification-stages
[pulp axi]: https://github.com/pulp-platform/axi
[pulp hash]: https://github.com/pulp-platform/axi/tree/a256a3b86394fedf19e361047fccfdd7f6ef83e4
[prim patch]: ../../hw/vendor/patches/pulp_axi/0001_Primitives_from_lowRISC_used.patch
[assert patch]: ../../hw/vendor/patches/pulp_axi/0006_Add_Mailbox_Output_Assertions.patch
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[d1-commit]: https://github.com/lowRISC/mocha/commit/b6edc2ae5cdee9f1d4d1baa815921bb658c82613
[instantiation]: ../../hw/top_chip/rtl/top_chip_system.sv#L637
[output asserts]: https://github.com/lowRISC/mocha/blob/b6edc2ae5cdee9f1d4d1baa815921bb658c82613/hw/vendor/pulp_axi/src/axi_lite_mailbox.sv#L191-L202
[lint waivers]: ../../hw/top_chip/lint/top_chip_system.vlt#L60-L69
[waivers issue]: https://github.com/lowRISC/mocha/issues/739
[V1 checklist]: stages.md#v1-verification-sign-off-checklist
[v1-commit]: https://github.com/lowRISC/mocha/commit/443dba606fc38dc9c3361f8c4fa18846bac41ed5
[spec issue]: https://github.com/lowRISC/mocha/issues/755
[Mailbox DV document]: ../../hw/ip/mailbox/dv/README.md
[Mailbox testplan]: ../../hw/ip/mailbox/data/mailbox_testplan.hjson
[tb.sv]: ../../hw/ip/mailbox/dv/tb/tb.sv
[cov model]: ../../hw/ip/mailbox/dv/env/mailbox_env_cov.sv
[COSMIC reports dashboard]: https://dashboard.reports.lowrisc.org/cosmic/mocha/dashboard.html
