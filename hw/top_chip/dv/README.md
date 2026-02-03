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
