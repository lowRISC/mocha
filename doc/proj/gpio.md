# GPIO

The GPIO in Mocha is generated with `ipgen` from the OpenTitan `gpio` IP template.
The documentation for the hardware IP block is its [theory of operation][theory], [register mapping][registers], and block [README][block doc].
The register mapping documentation is currently an empty stub but it will be generated once `cmdgen` is imported, as part of [issue #706][cmdgen].
The [Mocha configuration][ipconfig] declares no input period counters.
At the instantiation `GpioAsyncOn` is set so the inputs are synchronised, and hardware strap sampling is disabled, so `sampled_straps_o` is unused.
The [vendor patch][patch] only fixes DV paths and the default simulator in the templates; no RTL is modified.

The rest of this document contains the design checklist for the GPIO hardware IP block for the CHERI Mocha top.
For more details on the stages and the current state for each block, please refer to the [stages documentation][stages].

## Design sign-offs

### D1

The GPIO used for D1 sign-off is generated from the OpenTitan template at revision [bf4a2b2][OpenTitan hash], where it was [signed off to D1][OpenTitan D1 sign-off].
The sign-off checklist items are described in the [D1 design sign-off checklist][D1 checklist].
This sign-off is based on commit [b597321][d1-commit].

| Type          | Item                       | Status | Note/Collaterals |
|---------------|----------------------------|--------|------------------|
| Documentation | SPEC_COMPLETED             | Done   | [Theory of operation][theory] and [programmer's guide][pguide].
| Documentation | CSR_DEFINED                | Done   | Registers are defined in [gpio.hjson][csrs] and generated into `gpio_reg_pkg.sv` and `gpio_reg_top.sv`.
| RTL           | CLKRST_CONNECTED           | Done   | Modules containing submodules checked: `gpio.sv` and `gpio_reg_top.sv`. Modules without clocks and resets are confirmed to be purely combinational: `prim_onehot_enc`, `prim_subreg_ext`, `tlul_cmd_intg_chk` and `tlul_rsp_intg_gen`.
| RTL           | IP_TOP                     | Done   | This module is defined in `gpio.sv`.
| RTL           | IP_INSTANTIABLE            | Done   | It is instantiated in top chip system.
| RTL           | PHYSICAL_MACROS_DEFINED_80 | N/A    | No memory macros or analogue components.
| RTL           | FUNC_IMPLEMENTED           | Done   | All functionality already implemented.
| RTL           | ASSERT_KNOWN_ADDED         | Done   | Output assertions are [here][output asserts] and cover every output.
| Code Quality  | LINT_SETUP                 | Done   | Verilator lint target with `-Wall` in `gpio.core` and in the top. The block lints clean with no warnings in its own RTL.

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

[block doc]: ../../hw/top_chip/ip_autogen/gpio/README.md
[stages]: stages.md
[cmdgen]: https://github.com/lowRISC/mocha/issues/706
[missing asserts]: https://github.com/lowRISC/mocha/issues/711
[design stages]: stages.md#design-stages
[verification stages]: stages.md#verification-stages
[OpenTitan hash]: https://github.com/lowRISC/opentitan/tree/bf4a2b24e41742151cfce9c4041e959a3ba76ca3
[OpenTitan D1 sign-off]: https://github.com/lowRISC/opentitan/pull/676
[D1 checklist]: stages.md#d1-design-sign-off-checklist
[d1-commit]: https://github.com/lowRISC/mocha/commit/b5973217f704923917e7761f73df7dfcb8d0c345
[registers]: ../../hw/top_chip/ip_autogen/gpio/doc/registers.md
[csrs]: ../../hw/top_chip/ip_autogen/gpio/data/gpio.hjson
[theory]: ../../hw/top_chip/ip_autogen/gpio/doc/theory_of_operation.md
[pguide]: ../../hw/top_chip/ip_autogen/gpio/doc/programmers_guide.md
[ipconfig]: ../../hw/top_chip/data/gpio_cfg.hjson
[output asserts]: ../../hw/top_chip/ip_autogen/gpio/rtl/gpio.sv#L242-L249
[ot checklist]: ../../hw/top_chip/ip_autogen/gpio/doc/checklist.md
[patch]: ../../hw/vendor/patches/lowrisc_ip/gpio/0001_fix_paths_and_tool.patch
