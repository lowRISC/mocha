# KMAC

The KMAC in Mocha is imported from OpenTitan.
The documentation for the hardware IP block is located [in the vendored HW directory tree][block doc].
Mocha instantiates it only to check the ROM contents at boot: masking is disabled and the register, key manager, EDN, life cycle and interrupt interfaces are unused; their inputs are tied off to their respective package default values and their outputs are left unconnected.
The [vendor patches][patch] declare the sideload key and EDN types in `kmac_pkg` to drop the `keymgr_pkg` and `edn_pkg` dependencies, adapt the DV environment to Mocha, and add the [missing output known assertions][missing asserts]; the logic is unchanged.

The rest of this document contains the design checklist for the KMAC hardware IP block for the CHERI Mocha top.

## Design sign-offs

### D1

The KMAC used for D1 sign-off is the one imported from OpenTitan at revision [bf4a2b2][OpenTitan hash].
The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].
This sign-off is based on commit [3824b31][d1-commit].

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | [KMAC specification][block doc].
| Documentation | CSR_DEFINED                | Done   | [KMAC registers][registers].
| RTL           | CLKRST_CONNECTED           | Done   | Modules containing submodules checked: `kmac.sv`, `kmac_core.sv`, `kmac_app.sv`, `kmac_entropy.sv`, `kmac_errchk.sv`, `kmac_msgfifo.sv`, `kmac_staterd.sv`, `kmac_reg_top.sv`, `sha3.sv`, `sha3pad.sv`, `keccak_round.sv` and `keccak_2share.sv`. Modules without clocks and resets are confirmed to be purely combinational: `prim_sec_anchor_buf`, `prim_slicer`, `prim_subreg_ext`, `tlul_cmd_intg_chk` and `tlul_rsp_intg_gen`.
| RTL           | IP_TOP                     | Done   | This module is defined in `kmac.sv`.
| RTL           | IP_INSTANTIABLE            | Done   | It is instantiated in top chip system.
| RTL           | PHYSICAL_MACROS_DEFINED_80 | Done   | No memory macros or analogue components. The FIFO depths are fixed.
| RTL           | FUNC_IMPLEMENTED           | Done   | All functionality already implemented. Mocha exercises only the unmasked application interface path.
| RTL           | ASSERT_KNOWN_ADDED         | Done   | Output assertions are [here][output asserts] and cover every output.
| Code Quality  | LINT_SETUP                 | Done   | Verilator lint target with `-Wall` in `kmac.core` and in the top. The hidden enum value and circular combinational logic warnings [are waived][lint waivers]; the unused clock and width warnings are waived [in the block][block waivers].

### D2

*Checklist to be defined - see [stages.md][design stages].*

### D3

*Checklist to be defined - see [stages.md][design stages].*

## Verification sign-offs

### V1

All checklist items refer to the [V1 verification sign-off checklist][V1 checklist].
This sign-off is based on commit [`4c320ef`][v1-commit].

| Type          | Item                               | Status | Note/Collaterals |
|---------------|------------------------------------|--------|------------------|
| Documentation | DV_DOC_DRAFT_COMPLETED             | Done   | [KMAC DV document][] describes the goals, testbench architecture, stimulus, coverage, and checking strategy |
| Documentation | TESTPLAN_COMPLETED                 | Done   | [KMAC testplan][] defines the V1 smoke test and post-V1 message length, burst write, test vector, sideload, application interface, entropy, error, life cycle escalation and stress testpoints |
| Testbench     | TB_TOP_CREATED                     | Done   | [tb.sv][] instantiates the clock and reset, shadowed reset, EDN clock and reset, TileLink, EDN, application interface, key sideload, life cycle escalation, interrupt and alert interfaces along with the KMAC DUT |
| Testbench     | PRELIMINARY_ASSERTION_CHECKS_ADDED | Done   | [kmac_bind.sv][] binds the TLUL protocol and CSR assertions; the KMAC RTL checks that outputs are known after reset |
| Integration   | PRE_VERIFIED_SUB_MODULES_V1        | Waived | The SHA3 core is part of KMAC and is verified by this testbench. The remaining submodules are shared OpenTitan primitives and TileLink adapters (`prim_fifo_sync`, `prim_packer_fifo`, `prim_count`, `tlul_adapter_sram`, `tlul_adapter_reg`, etc.), unmodified in Mocha. They are covered through the IPs that instantiate them, so none carries an independent V1 sign-off |
| Review        | DESIGN_SPEC_REVIEWED               | Done   | The specification was reviewed through the OpenTitan sign-off process, where KMAC 2.1.0 reached V1. The [theory of operation][theory] was reviewed against the Mocha instantiation for this sign-off. It describes the Keccak round, padding, message FIFO and application interface correctly, but it is written for the OpenTitan configuration: Mocha builds KMAC unmasked and uses it only for the ROM check, so the TileLink, key manager, EDN and life cycle inputs are tied off, all three application interfaces take the ROM controller configuration with only the first connected, and the alert and interrupt outputs are left unconnected at the [instantiation][instantiation] |
| Review        | TESTPLAN_REVIEWED                  | Done   | OpenTitan lists the vendored KMAC 2.1.0 at V1, and the [OpenTitan KMAC checklist][ot checklist] records the testplan review as complete. The V1 testpoints of the [KMAC testplan][], `smoke` plus the imported CSR and memory testpoints, apply as written. The smoke test drives KMAC from software only. The block testbench keeps the Earlgrey application configuration, so index 0 is the key manager configuration, whereas Mocha uses `AppCfgRomCtrl` on every index at the [instantiation][instantiation]; only the chip-level `kmac_rom_app_test` exercises it. Aligning the block testbench for V2 is tracked in [issue #819][app cfg issue] |
| Review        | STD_TEST_CATEGORIES_PLANNED        | Done   | Error scenarios, throughput and stress tests are covered in the [KMAC testplan][]; security countermeasures are captured in the sec_cm testplan, but V2S is not used in Mocha; power and debug are N/A |
| Simulation    | SIM_TB_ENV_CREATED                 | Done   | CIP-based UVM environment with TL, EDN, application interface and key sideload agents, a DPI reference model and scoreboard |
| Tests         | SIM_SMOKE_TEST_PASSING             | Done   | All V1 testpoints (`kmac_smoke`, the five CSR tests, `kmac_mem_walk` and `kmac_mem_partial_access`): 40/40 passed, 5 seeds each, with Xcelium on November 18, 2026 at commit `4c320ef` |
| Regression    | SIM_SMOKE_REGRESSION_SETUP         | Done   | `smoke` regression in `kmac_base_sim_cfg.hjson` selects `kmac_smoke`; the aggregate Mocha config imports the unmasked simulation config, matching the Mocha instantiation |
| Regression    | SIM_NIGHTLY_REGRESSION_SETUP       | Done   | KMAC is included in `mocha_sim_cfgs.hjson`; results are published on the [COSMIC reports dashboard][] |
| Coverage      | SIM_COVERAGE_MODEL_ADDED           | Done   | Functional coverage is in `kmac_env_cov.sv`, with block-level coverage in `kmac_cov_if.sv`, bound into the DUT by `kmac_cov_bind.sv` |
| Tests         | FPV_MAIN_ASSERTIONS_PROVEN         | N/A    | This V1 sign-off uses simulation; TLUL and CSR assertions are enabled in the simulation testbench |
| Regression    | FPV_REGRESSION_SETUP               | N/A    | No KMAC FPV regression is configured in Mocha |

### V2

*Checklist to be defined - see [stages.md][verification stages].*

### V3

*Checklist to be defined - see [stages.md][verification stages].*

[block doc]: ../../hw/vendor/lowrisc_ip/ip/kmac/README.md
[missing asserts]: https://github.com/lowRISC/mocha/issues/707
[design stages]: stages.md#hardware-ip-block-design-stages
[verification stages]: stages.md#hardware-ip-block-verification-stages
[OpenTitan hash]: https://github.com/lowRISC/opentitan/tree/bf4a2b24e41742151cfce9c4041e959a3ba76ca3
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[d1-commit]: https://github.com/lowRISC/mocha/commit/3824b3167f3691f0a0259f2d85c43b022ac56c1a
[registers]: ../../hw/vendor/lowrisc_ip/ip/kmac/doc/registers.md
[output asserts]: https://github.com/lowRISC/mocha/blob/3824b3167f3691f0a0259f2d85c43b022ac56c1a/hw/vendor/lowrisc_ip/ip/kmac/rtl/kmac.sv#L1531-L1540
[ot checklist]: ../../hw/vendor/lowrisc_ip/ip/kmac/doc/checklist.md
[app cfg issue]: https://github.com/lowRISC/mocha/issues/819
[lint waivers]: ../../hw/top_chip/lint/top_chip_system.vlt
[block waivers]: ../../hw/vendor/lowrisc_ip/ip/kmac/lint/kmac.vlt
[patch]: ../../hw/vendor/patches/lowrisc_ip/kmac
[V1 checklist]: stages.md#v1-verification-sign-off-checklist
[v1-commit]: https://github.com/lowRISC/mocha/commit/4c320ef82c8e3f46acc69f069dc7c22f9c34d301
[theory]: ../../hw/vendor/lowrisc_ip/ip/kmac/doc/theory_of_operation.md
[instantiation]: https://github.com/lowRISC/mocha/blob/4c320ef82c8e3f46acc69f069dc7c22f9c34d301/hw/top_chip/rtl/top_chip_system.sv#L1452-L1491
[KMAC DV document]: ../../hw/vendor/lowrisc_ip/ip/kmac/dv/README.md
[KMAC testplan]: ../../hw/vendor/lowrisc_ip/ip/kmac/data/kmac_testplan.hjson
[tb.sv]: ../../hw/vendor/lowrisc_ip/ip/kmac/dv/tb.sv
[kmac_bind.sv]: ../../hw/vendor/lowrisc_ip/ip/kmac/dv/sva/kmac_bind.sv
[COSMIC reports dashboard]: https://dashboard.reports.lowrisc.org/cosmic/mocha/dashboard.html
