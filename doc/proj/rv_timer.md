# Timer

The Timer in Mocha is imported from OpenTitan.
The documentation for the hardware IP block is located [in the vendored HW directory tree][block doc].
It is a 64-bit RISC-V machine timer with a 12-bit prescaler and an 8-bit step register, compliant with the RISC-V privileged specification.
The number of timers per hart and the number of harts are configurable, but the implementation connects one timer for one hart, which is what Mocha uses.
The [vendor patches][patch] only fix DV paths and the default simulator; no RTL is modified.

The rest of this document contains the design checklist for the Timer hardware IP block for the CHERI Mocha top.
For more details on the stages and the current state for each block, please refer to the [stages documentation][stages].

## Design sign-offs

### D1

The Timer used for D1 sign-off is the one imported from OpenTitan at revision [`bf4a2b2`][OpenTitan hash], where it was signed off in [this pull request][OpenTitan D1 sign-off].
The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].
This sign-off is based on commit [`b597321`][d1-commit].

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | [Timer specification][block doc].
| Documentation | CSR_DEFINED                | Done   | [Timer registers][registers].
| RTL           | CLKRST_CONNECTED           | Done   | Modules containing submodules checked: `rv_timer.sv` and `rv_timer_reg_top.sv`. Modules without clocks and resets are confirmed to be purely combinational: `prim_onehot_enc`, `prim_subreg_ext`, `tlul_cmd_intg_chk` and `tlul_rsp_intg_gen`. The shared `prim_*` and `tlul_*` submodules are covered by their own OpenTitan sign-offs and are not walked here.
| RTL           | IP_TOP                     | Done   | This module is defined in `rv_timer.sv`.
| RTL           | IP_INSTANTIABLE            | Done   | It is instantiated in top chip system.
| RTL           | PHYSICAL_MACROS_DEFINED_80 | Done   | No memory macros or analogue components.
| RTL           | FUNC_IMPLEMENTED           | Done   | All functionality already implemented.
| RTL           | ASSERT_KNOWN_ADDED         | Done   | Output assertions are [here][output asserts] and cover every output.
| Code Quality  | LINT_SETUP                 | Done   | Verilator lint target with `-Wall` in `rv_timer.core` and in the top. The block lints clean with no warnings in its own RTL.

### D2

*Checklist to be defined — see [stages.md][design stages].*

### D3

*Checklist to be defined — see [stages.md][design stages].*

## Verification sign-offs

### V1

*Not yet started — see [stages.md][verification stages].*

### V2

*Checklist to be defined — see [stages.md][verification stages].*

### V3

*Checklist to be defined — see [stages.md][verification stages].*

[block doc]: ../../hw/vendor/lowrisc_ip/ip/rv_timer/README.md
[stages]: stages.md
[design stages]: stages.md#design-stages
[verification stages]: stages.md#verification-stages
[OpenTitan hash]: https://github.com/lowRISC/opentitan/tree/bf4a2b24e41742151cfce9c4041e959a3ba76ca3
[OpenTitan D1 sign-off]: https://github.com/lowRISC/opentitan/pull/652
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[d1-commit]: https://github.com/lowRISC/mocha/commit/b5973217f704923917e7761f73df7dfcb8d0c345
[registers]: ../../hw/vendor/lowrisc_ip/ip/rv_timer/doc/registers.md
[output asserts]: ../../hw/vendor/lowrisc_ip/ip/rv_timer/rtl/rv_timer.sv#L173-L178
[patch]: ../../hw/vendor/patches/lowrisc_ip/rv_timer
