# Clock manager

The Clock manager in Mocha is generated with `ipgen` from the OpenTitan `clkmgr` IP template.
The documentation for the hardware IP block is its [theory of operation][theory], [register mapping][registers], and block [README][block doc].
The README is currently a stub; the theory of operation is still the OpenTitan EarlGray configuration.
Both will be updated for Mocha as part of [issue #709][block doc issue].
The register mapping documentation is currently an empty stub but it will be generated once `cmdgen` is imported, as part of [issue #706][cmdgen].
The [Mocha configuration][ipconfig] declares `main`, `io` and `aon` source clocks, no derived clocks, one software-gated clock and one hint clock.
At the top all three source clocks are driven by the same chip clock, and the idle hint, jitter enable and clock gating indications are tied off or unused.
`ext_clk_bypass` is false, so there is no external clock bypass or calibration-ready input and `calib_rdy` is tied to `MuBi4False`, which clears any measurement enable software writes.

The rest of this document contains the design checklist for the Clock manager hardware IP block for the CHERI Mocha top.
For more details on the stages and the current state for each block, please refer to the [stages documentation][stages].

## Design sign-offs

### D1

The Clock manager used for D1 sign-off is generated from the OpenTitan template at revision [bf4a2b2][OpenTitan hash].
The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].
This sign-off is based on commit [b597321][d1-commit].

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Waived | [Theory of operation][theory] and [programmer's guide][pguide]. The README is a stub and the theory of operation still describes the OpenTitan configuration; both are tracked by [issue #709][block doc issue].
| Documentation | CSR_DEFINED                | Done   | Registers are defined in [clkmgr.hjson][csrs] and generated into `clkmgr_reg_pkg.sv` and `clkmgr_reg_top.sv`.
| RTL           | CLKRST_CONNECTED           | Done   | Modules containing submodules checked: `clkmgr.sv`, `clkmgr_root_ctrl.sv`, `clkmgr_trans.sv`, `clkmgr_meas_chk.sv`, `clkmgr_clk_status.sv` and `clkmgr_reg_top.sv`. Modules without clocks and resets are confirmed to be purely combinational: `prim_buf`, `prim_subreg_ext`, `tlul_cmd_intg_chk` and `tlul_rsp_intg_gen`. The clock cells `prim_clock_buf` and `prim_clock_gating` take a clock and no reset.
| RTL           | IP_TOP                     | Done   | This module is defined in `clkmgr.sv`.
| RTL           | IP_INSTANTIABLE            | Done   | It is instantiated in top chip system.
| RTL           | PHYSICAL_MACROS_DEFINED_80 | N/A    | No memory macros or analogue components. The clock sources arrive as ports.
| RTL           | FUNC_IMPLEMENTED           | Done   | All functionality already implemented. Frequency measurement is disabled by the Mocha configuration.
| RTL           | ASSERT_KNOWN_ADDED         | Done   | Output assertions are [here][output asserts] and cover every output.
| Code Quality  | LINT_SETUP                 | Done   | Verilator lint target with `-Wall` in `clkmgr.core` and in the top. The block lints clean with no warnings in its own RTL.

### D2

*Checklist to be defined - see [stages.md][design stages].*

### D3

*Checklist to be defined - see [stages.md][design stages].*

## Verification sign-offs

### V1

*Not yet started - see [stages.md][verification stages].*

### V2

*Checklist to be defined - see [stages.md][verification stages].*

### V3

*Checklist to be defined - see [stages.md][verification stages].*

[block doc]: ../../hw/top_chip/ip_autogen/clkmgr/README.md
[stages]: stages.md
[block doc issue]: https://github.com/lowRISC/mocha/issues/709
[cmdgen]: https://github.com/lowRISC/mocha/issues/706
[design stages]: stages.md#hardware-ip-block-design-stages
[verification stages]: stages.md#hardware-ip-block-verification-stages
[OpenTitan hash]: https://github.com/lowRISC/opentitan/tree/bf4a2b24e41742151cfce9c4041e959a3ba76ca3
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[d1-commit]: https://github.com/lowRISC/mocha/commit/b5973217f704923917e7761f73df7dfcb8d0c345
[registers]: ../../hw/top_chip/ip_autogen/clkmgr/doc/registers.md
[csrs]: ../../hw/top_chip/ip_autogen/clkmgr/data/clkmgr.hjson
[theory]: ../../hw/top_chip/ip_autogen/clkmgr/doc/theory_of_operation.md
[pguide]: ../../hw/top_chip/ip_autogen/clkmgr/doc/programmers_guide.md
[ipconfig]: ../../hw/top_chip/ip_autogen/clkmgr/data/mocha_clkmgr.ipconfig.hjson
[output asserts]: https://github.com/lowRISC/mocha/blob/b5973217f704923917e7761f73df7dfcb8d0c345/hw/top_chip/ip_autogen/clkmgr/rtl/clkmgr.sv#L483-L490
