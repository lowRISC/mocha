# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set(LIBS hal runtime startup test_framework)

mocha_add_test(NAME test_framework_test SOURCES test_framework/smoketest.c LIBRARIES ${LIBS} TIMEOUT 20)
mocha_add_test(NAME test_framework_exception_test SOURCES test_framework/exception.c LIBRARIES ${LIBS})
mocha_add_test(NAME axi_sram_smoketest SOURCES axi_sram/smoketest.c LIBRARIES ${LIBS})
mocha_add_test(NAME axi_sram_tag_test SOURCES axi_sram/tag_test.c LIBRARIES ${LIBS})
mocha_add_test(NAME gpio_reg_access_test SOURCES gpio/reg_access_test.c LIBRARIES ${LIBS})
# Can't run this test on FPGA or verilator tops and this test thinks that the GPIO inputs can be
# driven externally
mocha_add_test(NAME gpio_smoketest SOURCES gpio/smoketest.c LIBRARIES ${LIBS} SKIP_VERILATOR SKIP_FPGA)
mocha_add_test(NAME i2c_smoketest SOURCES i2c/smoketest.c LIBRARIES ${LIBS})
mocha_add_test(NAME mailbox_smoketest SOURCES mailbox/smoketest.c LIBRARIES ${LIBS})
mocha_add_test(NAME plic_smoketest SOURCES plic/smoketest.c LIBRARIES ${LIBS})
# Cannot currently run this on FPGA because the boot ROM expects the test to be provided on the SPI again.
mocha_add_test(NAME rstmgr_smoketest SOURCES rstmgr/smoketest.c LIBRARIES ${LIBS})
mocha_add_test(NAME spi_device_smoketest SOURCES spi_device/smoketest.c LIBRARIES ${LIBS})
mocha_add_test(NAME spi_host_smoketest SOURCES spi_host/smoketest.c LIBRARIES ${LIBS})
mocha_add_test(NAME tag_controller_smoketest SOURCES tag_controller/smoketest.c LIBRARIES ${LIBS})
mocha_add_test(NAME tag_controller_tag_test SOURCES tag_controller/tag_test.c LIBRARIES ${LIBS})
mocha_add_test(NAME timer_smoketest SOURCES timer/smoketest.c LIBRARIES ${LIBS})
mocha_add_test(NAME timer_interrupt_test SOURCES timer/interrupt.c LIBRARIES ${LIBS})
mocha_add_test(NAME uart_smoketest SOURCES uart/smoketest.c LIBRARIES ${LIBS})
mocha_add_test(NAME isa_atomics SOURCES isa/atomics.c LIBRARIES ${LIBS})

add_subdirectory(opensbi)
