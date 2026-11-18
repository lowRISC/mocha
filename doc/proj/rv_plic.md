# PLIC

The PLIC in Mocha is generated with `ipgen` from the OpenTitan `rv_plic` IP template.
The documentation for the hardware IP block is its [theory of operation][theory], [programmer's guide][pguide] and block [README][block doc].
It is a RISC-V platform-level interrupt controller: it collects the peripheral interrupt lines, applies a per-source priority and a per-target threshold, and raises the external interrupt to the core.
The block has no generated register mapping document; the registers are described in [rv_plic.hjson][csrs] and will be rendered once cmdgen is imported, as part of [issue #706][cmdgen].
The [vendor patches][patch] adjust the context interrupt enable stride and add the missing alert output known assertion; no datapath logic is changed.

The rest of this document contains the design checklist for the PLIC hardware IP block for the CHERI Mocha top.
For more details on the stages and the current state for each block, please refer to the [stages documentation][stages].

## Design sign-offs

### D1

The PLIC used for D1 sign-off is generated from the OpenTitan template at revision [`bf4a2b2`][OpenTitan hash], where it reached D2 in [this pull request][OpenTitan sign-off].
The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].
This sign-off is based on commit [`272c57d`][d1-commit].

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | [Theory of operation][theory] and [programmer's guide][pguide].
| Documentation | CSR_DEFINED                | Done   | Registers are defined in [rv_plic.hjson][csrs] and generated into `rv_plic_reg_pkg.sv` and `rv_plic_reg_top.sv`.
| RTL           | CLKRST_CONNECTED           | Done   | Modules containing submodules checked: `rv_plic.sv`, `rv_plic_target.sv` and `rv_plic_reg_top.sv`. Modules without clocks and resets are confirmed to be purely combinational: `prim_subreg_ext`, `tlul_cmd_intg_chk` and `tlul_rsp_intg_gen`. The shared `prim_*` and `tlul_*` submodules are covered by their own OpenTitan sign-offs and are not walked here.
| RTL           | IP_TOP                     | Done   | This module is defined in `rv_plic.sv`.
| RTL           | IP_INSTANTIABLE            | Done   | It is instantiated in top chip system.
| RTL           | PHYSICAL_MACROS_DEFINED_80 | Done   | No memory macros or analogue components.
| RTL           | FUNC_IMPLEMENTED           | Done   | All functionality already implemented.
| RTL           | ASSERT_KNOWN_ADDED         | Done   | Output assertions are [here][output asserts] and cover every output.
| Code Quality  | LINT_SETUP                 | Done   | Verilator lint target with `-Wall` in `rv_plic.core` and in the top. The block lints clean with no warnings in its own RTL.

### D2

*Checklist to be defined - see [stages.md][design stages].*

### D3

*Checklist to be defined - see [stages.md][design stages].*

## Verification sign-offs

### V1

All checklist items refer to the [V1 verification sign-off checklist][V1 checklist].
This sign-off is based on commit [`4c320ef`][v1-commit].
The PLIC is verified with formal property verification only, as upstream, so the simulation items are N/A.

| Type          | Item                               | Status | Note/Collaterals |
|---------------|------------------------------------|--------|------------------|
| Documentation | DV_DOC_DRAFT_COMPLETED             | Done   | [PLIC DV document][] describes the FPV goals, testbench architecture, assertions and the symbolic variables used to pick one source and one target |
| Documentation | TESTPLAN_COMPLETED                 | Done   | [PLIC FPV testplan][] lists the functional properties of the interrupt gateway, claim and completion flow and target notification, each mapped to the assertion that checks it |
| Testbench     | TB_TOP_CREATED                     | Done   | [rv_plic_tb.sv][] instantiates the PLIC DUT with every port driven or observed by the formal tool |
| Testbench     | PRELIMINARY_ASSERTION_CHECKS_ADDED | Done   | [rv_plic_bind_fpv.sv][] binds the TLUL protocol assertions, the generated CSR assertions and the PLIC functional assertions in [rv_plic_assert_fpv.sv][]; the PLIC RTL checks that outputs are known after reset |
| Integration   | PRE_VERIFIED_SUB_MODULES_V1        | Waived | The submodules are shared OpenTitan primitives and TileLink adapters (`prim_max_tree`, `prim_subreg`, `prim_alert_sender`, `tlul_adapter_reg`, etc.), unmodified in Mocha. Their embedded assertions are part of the PLIC proof; the [OpenTitan PLIC checklist][] records this item as N/A |
| Review        | DESIGN_SPEC_REVIEWED               | Done   | The specification was reviewed through the OpenTitan sign-off process, where the block reached V2, and the [theory of operation][theory] was reviewed against the Mocha configuration for this sign-off. It describes the gateways, priorities, thresholds, enables and the claim and completion flow correctly for the 32 sources, 2 targets and 2-bit priorities Mocha generates. All sources are level triggered. Mocha has no alert handler, and CVA6-CHERI reads the claimed ID from the claim register, so `alert_tx_o`, `irq_id_o` and `msip_o` are left unconnected at the [instantiation][instantiation] |
| Review        | TESTPLAN_REVIEWED                  | Done   | The [OpenTitan PLIC checklist][] records the testplan review as complete upstream. The testpoints of the [PLIC FPV testplan][] apply to the Mocha configuration as written; upstream stages them all at V2, and their assertions are already proven for this sign-off |
| Review        | STD_TEST_CATEGORIES_PLANNED        | N/A    | Formal proofs cover every reachable state rather than planned scenarios; the [OpenTitan PLIC checklist][] records this item as N/A |
| Simulation    | SIM_TB_ENV_CREATED                 | N/A    | The PLIC is verified with FPV only |
| Tests         | SIM_SMOKE_TEST_PASSING             | N/A    | The PLIC is verified with FPV only |
| Regression    | SIM_SMOKE_REGRESSION_SETUP         | N/A    | The PLIC is verified with FPV only |
| Regression    | SIM_NIGHTLY_REGRESSION_SETUP       | N/A    | The PLIC is verified with FPV only |
| Coverage      | SIM_COVERAGE_MODEL_ADDED           | N/A    | The PLIC is verified with FPV only |
| Tests         | FPV_MAIN_ASSERTIONS_PROVEN         | Done   | JasperGold on November 18, 2026 at commit `4c320ef`: 123 assertions proven with no counterexamples or undetermined properties, and 124 covers hit. The 4 write-enable one-hot checks run in a separate task, and their 3 precondition covers are the [expected unreachable covers][exp fail]. Every input and output is part of at least one assertion; `msip_o` is only covered by a known check, and the MSIP registers it copies by the CSR read assertions |
| Regression    | FPV_REGRESSION_SETUP               | Done   | `rv_plic_fpv` is registered in [top_chip_fpv_ip_cfgs.hjson][fpv cfgs] with formal coverage enabled and the [expected unreachable covers][exp fail] listed |

### V2

*Checklist to be defined - see [stages.md][verification stages].*

### V3

*Checklist to be defined - see [stages.md][verification stages].*

[block doc]: ../../hw/top_chip/ip_autogen/rv_plic/README.md
[stages]: stages.md
[design stages]: stages.md#hardware-ip-block-design-stages
[verification stages]: stages.md#hardware-ip-block-verification-stages
[OpenTitan hash]: https://github.com/lowRISC/opentitan/tree/bf4a2b24e41742151cfce9c4041e959a3ba76ca3
[OpenTitan sign-off]: https://github.com/lowRISC/opentitan/pull/1480
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[d1-commit]: https://github.com/lowRISC/mocha/commit/272c57d8d91556f7c7889123c5da3bcf51dd8345
[theory]: ../../hw/top_chip/ip_autogen/rv_plic/doc/theory_of_operation.md
[pguide]: ../../hw/top_chip/ip_autogen/rv_plic/doc/programmers_guide.md
[csrs]: ../../hw/top_chip/ip_autogen/rv_plic/data/rv_plic.hjson
[cmdgen]: https://github.com/lowRISC/mocha/issues/706
[output asserts]: https://github.com/lowRISC/mocha/blob/272c57d8d91556f7c7889123c5da3bcf51dd8345/hw/top_chip/ip_autogen/rv_plic/rtl/rv_plic.sv#L276-L284
[patch]: ../../hw/vendor/patches/lowrisc_ip/rv_plic
[V1 checklist]: stages.md#v1-verification-sign-off-checklist
[v1-commit]: https://github.com/lowRISC/mocha/commit/4c320ef82c8e3f46acc69f069dc7c22f9c34d301
[instantiation]: https://github.com/lowRISC/mocha/blob/4c320ef82c8e3f46acc69f069dc7c22f9c34d301/hw/top_chip/rtl/top_chip_system.sv#L911-L930
[PLIC DV document]: ../../hw/top_chip/ip_autogen/rv_plic/doc/dv/README.md
[PLIC FPV testplan]: ../../hw/top_chip/ip_autogen/rv_plic/data/rv_plic_fpv_testplan.hjson
[rv_plic_tb.sv]: ../../hw/top_chip/ip_autogen/rv_plic/fpv/tb/rv_plic_tb.sv
[rv_plic_bind_fpv.sv]: ../../hw/top_chip/ip_autogen/rv_plic/fpv/tb/rv_plic_bind_fpv.sv
[rv_plic_assert_fpv.sv]: ../../hw/top_chip/ip_autogen/rv_plic/fpv/vip/rv_plic_assert_fpv.sv
[OpenTitan PLIC checklist]: ../../hw/top_chip/ip_autogen/rv_plic/doc/checklist.md
[fpv cfgs]: ../../hw/top_chip/formal/top_chip_fpv_ip_cfgs.hjson
[exp fail]: ../../hw/top_chip/ip_autogen/rv_plic/fpv/rv_plic_expected_failure.hjson
