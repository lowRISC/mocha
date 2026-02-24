# Top Level Verification

The Top Level verification environment is based on the approach used in [OpenTitan](https://github.com/lowRISC/opentitan/tree/master/hw/top_earlgrey/dv) and [Sunburst](https://github.com/lowRISC/sunburst-chip/tree/main/hw/top_chip/dv).

Unlike traditional pure UVM testbenches where UVM Sequences drive all stimulus, this environment is primarily **Software Driven**.
The CPU executes a C program on the DUT, and the UVM environment acts as a reactive testbench, handling checking, monitoring, and providing stimulus only when requested by the software.

## Verification Philosophy

Currently, the top-level approach is focused on **Validation** rather than pure Verification, with a long-term goal of **Co-Verification**.

* **Verification:** Answers *"Are we building the product right?"* (Does the RTL match the specification?).
* **Validation:** Answers *"Are we building the right product?"* (Does the system function correctly in its intended real-world environment?).

The software tests running on the simulated CPU are often "auto-verifying," meaning the C code itself checks if the operation succeeded (e.g., a UART loopback test checking that received data matches sent data).
The UVM environment's role is to facilitate this execution (loading memory, handling clocks) and provide secondary checks.

## Simulation Flow

The simulation is orchestrated by `dvsim`, which manages the build and run flow.

### 1. Launching the Simulation
A typical command to launch a test looks like this:

```bash
dvsim hw/top_chip/dv/top_chip_sim_cfg.hjson -i uart_smoke -t xcelium
```

* `top_chip_sim_cfg.hjson`: The configuration file defining the build and run parameters.
* `-i uart_smoke`: Specifies the test case.
  This usually maps to a C program (e.g., `sw/device/tests/uart/smoketest.c`).
* `-t xcelium`: Specifies the simulator target.

### 2. Sequence Selection

The `dvsim` command generates a runtime argument `+UVM_TEST_SEQ=top_chip_dv_uart_base_vseq`.
The UVM execution flow is as follows:

1. The standard `run_test()` is called in `tb.sv`.
2. This invokes `top_chip_dv_base_test::run_test()`.
3. The test extracts the `UVM_TEST_SEQ` plusarg to determine which virtual sequence to execute.

### 3. Software Loading (Backdoor)

Because simulating the CPU boot ROM process is slow, we load the software binary directly into the DUT memory using a **UVM Backdoor**.

1.  **Compilation:** The C program (e.g., `sw/device/tests/uart/smoketest.c`) is compiled into a VMEM file (hex format).
2.  **Argument Passing:** `dvsim` passes the path to this file to the simulator via a runtime switch (plusarg):
    ```text
    +ChipMemSRAM_image_file={path}/uart_smoketest.vmem
    ```
3.  **Loading:**
    * A memory backdoor utility class (`mem_bkdr_util`) is initialized in the Testbench Top (`tb.sv`) pointing to the SRAM instance.
    * During the `load_memories` phase in `top_chip_dv_base_test`, the testbench reads this `+ChipMemSRAM_image_file` argument.
    * It reads the content of the specified VMEM file and writes it directly into the DUT's SRAM, bypassing the slow flash loading or ROM boot process.

## SW-to-DV Communication

To facilitate interactions between the Software and the DV environment, we utilize the **`sim_sram_axi`** module.
This is a special hardware block inserted only during simulation that intercepts AXI traffic.

For more details, see: [sim_sram_axi/README.md](./sim_sram_axi/README.md)

### Mechanism

1. **Interception:** The module "swallows" traffic destined for a specific Simulation Address Range (`SW_DV_START_ADDR`).
   Traffic outside this range is transparently forwarded to the AXI Crossbar.
2. **Binding:** In `tb.sv`, we `bind` verification interfaces (`sw_test_status_if` and `sw_logger_if`) to this module.

### Use Cases

* **Test Status:** The SW writes Pass/Fail status to `SW_DV_TEST_STATUS_ADDR`.
  The `sw_test_status_if` detects this and signals the UVM environment to terminate the simulation.
* **Logging:** The SW writes debug strings to `SW_DV_LOG_ADDR`.
  The `sw_logger_if` captures these characters and prints them to the simulation log, avoiding the latency of the UART peripheral.

## Simulation commands

### Run Simulations with `dvsim`
The `dvsim` command is used to build and run simulations, and also to manage regressions.
All simulation configurations are defined in HJSON files, which specify the DUT, test cases, and simulation arguments.
There are individual HJSON files for each IP block, as well as for the top-level (called `top_chip_sim_cfg.hjson`).
Another HJSON file called `mocha_sim_cfgs.hjson` aggregates all the individual test configurations for the various IPs and the top-level.
Here are some command examples:

```bash
# Run the top-level SW based UART smoke test
dvsim hw/top_chip/dv/top_chip_sim_cfg.hjson -i uart_smoke
# Run the top-level SW based smoke regression
dvsim hw/top_chip/dv/top_chip_sim_cfg.hjson -i smoke
# Run the same top-level SW based smoke regression but from the aggregated Mocha config file
dvsim hw/top_chip/dv/mocha_sim_cfgs.hjson --select-cfgs top_mocha_sim -i smoke
# Run the block-level UART smoke regression from the aggregated Mocha config file
dvsim hw/top_chip/dv/mocha_sim_cfgs.hjson --select-cfgs uart -i smoke
```

### Specify simulation options
#### DVSIM options
You can also specify additional simulation and simulator options from `dvsim`.
To know which options are available, you can run:
```bash
dvsim --help
```

The following are some examples of how to specify additional options:
```bash
# Run with a specific seed for reproducibility
dvsim hw/top_chip/dv/top_chip_sim_cfg.hjson -i uart_smoke -fs 123456789
# Run with a specific simulator (e.g., Xcelium)
dvsim hw/top_chip/dv/top_chip_sim_cfg.hjson -i uart_smoke -t xcelium
# Run simulation in interactive mode (opens the simulator GUI and enable interactive debugging)
dvsim hw/top_chip/dv/top_chip_sim_cfg.hjson -i uart_smoke -gd
# Change the default UVM verbosity level to UVM_DEBUG
dvsim hw/top_chip/dv/top_chip_sim_cfg.hjson -i uart_smoke -v d
```

#### Control UVM reporting and logging with plusargs

The UVM environment supports several runtime switches that can be passed to the simulator as plusargs to control the reporting and logging behavior.
See [uvm_cmdline_processor.svh](https://verificationacademy.com/verification-methodology-reference/uvm/docs_1.2/html/files/base/uvm_cmdline_processor-svh.html#uvm_cmdline_processor) for more details.
These plusargs can be specified from the DVSim command in the `run_opts` field of the test configuration in the HJSON file, or passed directly from the command line using the `--run-opts` flag.

Also, we have implemented a custom plusargs called `+max_quit_count` and `+test_timeout_ns` that can be used to control when the simulation should terminate.
Underneath the hood, these plusargs are calling the methods `uvm_report_server::set_max_quit_count()` and `uvm_root::set_timeout()` respectively.

Example usage:
```bash
# Limit the number of UVM_ERROR messages to 10
dvsim hw/top_chip/dv/top_chip_sim_cfg.hjson -i uart_smoke --run-opts "+max_quit_count=10"
# Set simulation timeout to 10,000 ns
dvsim hw/top_chip/dv/top_chip_sim_cfg.hjson -i uart_smoke --run-opts "+test_timeout_ns=10000"
```
