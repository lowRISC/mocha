# ROM control

The ROM control in Mocha is imported from OpenTitan.
The documentation for the hardware IP block is located [in the vendored HW directory tree][block doc].
It holds the boot ROM, descrambles its contents on the way out, and checks the ROM's integrity after reset before releasing the CPU.
Mocha instantiates it with scrambling enabled over a 32 KiB ROM, and drives the integrity check through the KMAC application interface, reporting the result to the power manager.
The [vendor patches][patch] only adjust testplan, simulation config and tool import paths, a DV core file, the ROM image scrambling script and the DV scrambler model; no RTL is modified.

The rest of this document contains the design checklist for the ROM control hardware IP block for the CHERI Mocha top.
For more details on the stages and the current state for each block, please refer to the [stages documentation][stages].

## Design sign-offs

### D1

The ROM control used for D1 sign-off is the one imported from OpenTitan at revision [`bf4a2b2`][OpenTitan hash], where it was signed off at D1 in [this pull request][OpenTitan D1 sign-off] and the [upstream checklist][OpenTitan ROM control checklist] records it past D1.
The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].
This sign-off is based on commit [`b597321`][d1-commit].

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | [ROM control specification][block doc].
| Documentation | CSR_DEFINED                | Done   | [ROM control registers][registers].
| RTL           | CLKRST_CONNECTED           | Done   | Modules containing submodules checked: `rom_ctrl.sv`, `rom_ctrl_fsm.sv`, `rom_ctrl_compare.sv`, `rom_ctrl_mux.sv`, `rom_ctrl_scrambled_rom.sv` and `rom_ctrl_regs_reg_top.sv`; `rom_ctrl_counter.sv` takes a clock and reset and instantiates no submodules. Modules without clocks and resets are confirmed to be purely combinational: `prim_buf`, `prim_sec_anchor_buf`, `prim_subreg_ext`, `prim_subst_perm`, `tlul_cmd_intg_chk` and `tlul_rsp_intg_gen`. The clocked shared submodules instantiated: `prim_alert_sender`, `prim_count`, `prim_fifo_sync`, `prim_flop`, `prim_mubi4_sender`, `prim_prince`, `prim_reg_we_check`, `prim_rom_adv`, `prim_subreg`, `tlul_adapter_reg` and `tlul_adapter_sram` have their clock and reset driven from the instantiating module and are not walked further, being covered by their own OpenTitan sign-offs.
| RTL           | IP_TOP                     | Done   | This module is defined in `rom_ctrl.sv`.
| RTL           | IP_INSTANTIABLE            | Done   | It is instantiated in top chip system.
| RTL           | PHYSICAL_MACROS_DEFINED_80 | Done   | The boot ROM is instantiated through `prim_rom_adv` in `rom_ctrl_scrambled_rom.sv`, fixed at 8192 entries of 39 bits by the 32 KiB `MemSizeRom` and scrambling being enabled. The [upstream checklist][OpenTitan ROM control checklist] records this as N/A; Mocha records it Done because the ROM macro is fixed by the Mocha configuration.
| RTL           | FUNC_IMPLEMENTED           | Done   | All functionality already implemented.
| RTL           | ASSERT_KNOWN_ADDED         | Done   | Output assertions are [here][output asserts] and cover every output.
| Code Quality  | LINT_SETUP                 | Done   | Verilator lint target with `-Wall` in `rom_ctrl.core` and in the top. The block target's own `lint/rom_ctrl.vlt` is empty; the unused signal, undriven and unoptimisable-flat warnings in `rom_ctrl.sv` [are waived][lint waivers] in the top lint flow only.

### D2

*Checklist to be defined - see [stages.md][design stages].*

### D3

*Checklist to be defined - see [stages.md][design stages].*

## Verification sign-offs

### V1

All checklist items refer to the [V1 verification sign-off checklist][V1 checklist].
This sign-off is based on commit [`d428cd9`][v1-commit].

| Type          | Item                               | Status | Note/Collaterals |
|---------------|------------------------------------|--------|------------------|
| Documentation | DV_DOC_DRAFT_COMPLETED             | Done   | [ROM control DV document][] describes the goals, testbench architecture, stimulus, coverage, and checking strategy |
| Documentation | TESTPLAN_COMPLETED                 | Done   | [ROM control testplan][] defines the V1 smoke test and post-V1 throughput, KMAC error, fatal error and stress testpoints |
| Testbench     | TB_TOP_CREATED                     | Done   | [tb.sv][] instantiates clock and reset, the register and ROM TileLink interfaces, the KMAC application interface, the memory backdoor utility and alert interfaces along with the ROM control DUT |
| Testbench     | PRELIMINARY_ASSERTION_CHECKS_ADDED | Done   | [rom_ctrl_bind.sv][] binds the TLUL protocol assertions on both TileLink interfaces and the CSR assertions; [tb.sv][] checks the KMAC and power manager handshakes; the ROM control RTL checks that outputs are known after reset |
| Integration   | PRE_VERIFIED_SUB_MODULES_V1        | Waived | The submodules are shared OpenTitan primitives and TileLink adapters (`prim_prince`, `prim_rom_adv`, `prim_count`, `tlul_adapter_sram`, `tlul_adapter_reg`, etc.), unmodified in Mocha. They are covered through the IPs that instantiate them, so none carries an independent V1 sign-off; the [OpenTitan ROM control checklist][] records this item as N/A |
| Review        | DESIGN_SPEC_REVIEWED               | Done   | The specification was reviewed through the OpenTitan sign-off process, where the block reached V2S, and the [theory of operation][theory] was reviewed against the Mocha instantiation for this sign-off. It describes the scrambled ROM, the checker FSM and the KMAC and power manager handshakes correctly, but it is written for the OpenTitan configuration: Mocha has no key manager or alert handler, so `keymgr_data_o` is [left unused][keymgr tie-off] and `alert_tx_o` is left open at the [instantiation][instantiation] |
| Review        | TESTPLAN_REVIEWED                  | Done   | The [OpenTitan ROM control checklist][] records the testplan review as complete upstream. The V1 testpoints of the [ROM control testplan][], `smoke` plus the imported CSR and memory testpoints, apply as written. The smoke checks on the digest sent to the key manager have no Mocha counterpart but remain valid at block level |
| Review        | STD_TEST_CATEGORIES_PLANNED        | Done   | Error scenarios, performance and stress tests are covered in the [ROM control testplan][]; security countermeasures are captured in the sec_cm testplan, but V2S is not used in Mocha; power and debug are N/A |
| Simulation    | SIM_TB_ENV_CREATED                 | Done   | CIP-based UVM environment with TL and KMAC application agents and scoreboard |
| Tests         | SIM_SMOKE_TEST_PASSING             | Done   | All V1 testpoints (`rom_ctrl_smoke`, the five CSR tests, `rom_ctrl_mem_walk` and `rom_ctrl_mem_partial_access`): 40/40 passed, 5 seeds each, with Xcelium on November 12, 2026 at commit `d428cd9` |
| Regression    | SIM_SMOKE_REGRESSION_SETUP         | Done   | `smoke` regression in `rom_ctrl_base_sim_cfg.hjson` selects `rom_ctrl_smoke`; the aggregate Mocha config imports the 32 KiB ROM control simulation config, matching the Mocha ROM size |
| Regression    | SIM_NIGHTLY_REGRESSION_SETUP       | Done   | ROM control is included in `mocha_sim_cfgs.hjson`; results are published on the [COSMIC reports dashboard][] |
| Coverage      | SIM_COVERAGE_MODEL_ADDED           | Done   | Block-level coverage is in `rom_ctrl_cov_if.sv`, bound into the DUT by `rom_ctrl_cov_bind.sv` |
| Tests         | FPV_MAIN_ASSERTIONS_PROVEN         | N/A    | This V1 sign-off uses simulation; TLUL and CSR assertions are enabled in the simulation testbench |
| Regression    | FPV_REGRESSION_SETUP               | N/A    | No ROM control FPV regression is configured in Mocha |

### V2

*Checklist to be defined - see [stages.md][verification stages].*

### V3

*Checklist to be defined - see [stages.md][verification stages].*

[block doc]: ../../hw/vendor/lowrisc_ip/ip/rom_ctrl/README.md
[stages]: stages.md
[design stages]: stages.md#hardware-ip-block-design-stages
[verification stages]: stages.md#hardware-ip-block-verification-stages
[OpenTitan hash]: https://github.com/lowRISC/opentitan/tree/bf4a2b24e41742151cfce9c4041e959a3ba76ca3
[OpenTitan D1 sign-off]: https://github.com/lowRISC/opentitan/pull/7114
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[d1-commit]: https://github.com/lowRISC/mocha/commit/b5973217f704923917e7761f73df7dfcb8d0c345
[registers]: ../../hw/vendor/lowrisc_ip/ip/rom_ctrl/doc/registers.md
[output asserts]: https://github.com/lowRISC/mocha/blob/b5973217f704923917e7761f73df7dfcb8d0c345/hw/vendor/lowrisc_ip/ip/rom_ctrl/rtl/rom_ctrl.sv#L519-L561
[lint waivers]: https://github.com/lowRISC/mocha/blob/b5973217f704923917e7761f73df7dfcb8d0c345/hw/top_chip/lint/top_chip_system.vlt#L317-L324
[OpenTitan ROM control checklist]: ../../hw/vendor/lowrisc_ip/ip/rom_ctrl/doc/checklist.md
[patch]: ../../hw/vendor/patches/lowrisc_ip/rom_ctrl
[V1 checklist]: stages.md#v1-verification-sign-off-checklist
[v1-commit]: https://github.com/lowRISC/mocha/commit/d428cd9580070a09722130daf1e37db0dd68b975
[theory]: ../../hw/vendor/lowrisc_ip/ip/rom_ctrl/doc/theory_of_operation.md
[instantiation]: https://github.com/lowRISC/mocha/blob/d428cd9580070a09722130daf1e37db0dd68b975/hw/top_chip/rtl/top_chip_system.sv#L1423-L1451
[keymgr tie-off]: https://github.com/lowRISC/mocha/blob/d428cd9580070a09722130daf1e37db0dd68b975/hw/top_chip/rtl/top_chip_system.sv#L367
[ROM control DV document]: ../../hw/vendor/lowrisc_ip/ip/rom_ctrl/dv/README.md
[ROM control testplan]: ../../hw/vendor/lowrisc_ip/ip/rom_ctrl/data/rom_ctrl_testplan.hjson
[tb.sv]: ../../hw/vendor/lowrisc_ip/ip/rom_ctrl/dv/tb/tb.sv
[rom_ctrl_bind.sv]: ../../hw/vendor/lowrisc_ip/ip/rom_ctrl/dv/sva/rom_ctrl_bind.sv
[COSMIC reports dashboard]: https://dashboard.reports.lowrisc.org/cosmic/mocha/dashboard.html
