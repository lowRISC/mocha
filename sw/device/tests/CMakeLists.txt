# Copyright lowRISC and contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set(LIBS hal runtime startup test_framework)

mocha_add_test(NAME test_framework_test SOURCES test_framework/smoketest.c LIBRARIES ${LIBS} VERILATOR_TIMEOUT 20 FPGA_TIMEOUT 10)
mocha_add_test(NAME test_framework_exception_test SOURCES test_framework/exception.c LIBRARIES ${LIBS})
mocha_add_test(NAME dv_log_smoketest SOURCES test_framework/dv_log_smoketest.c LIBRARIES ${LIBS} SKIP_VERILATOR SKIP_FPGA)
mocha_add_test(NAME axi_sram_smoketest SOURCES axi_sram/smoketest.c LIBRARIES ${LIBS})
mocha_add_test(NAME axi_sram_tag_test SOURCES axi_sram/tag_test.c LIBRARIES ${LIBS})
mocha_add_test(NAME axi_sram_tag_reset_test SOURCES axi_sram/tag_reset_test.c LIBRARIES ${LIBS})
mocha_add_test(NAME entropy_src_smoketest SOURCES entropy_src/smoketest.c LIBRARIES ${LIBS})
# Cannot run this on verilator as the ethernet MAC is not in the verilator top
mocha_add_test(NAME ethernet_smoketest SOURCES ethernet/smoketest.c LIBRARIES ${LIBS} SKIP_VERILATOR)
mocha_add_test(NAME clkmgr_smoketest SOURCES clkmgr/smoketest.c LIBRARIES ${LIBS})
mocha_add_test(NAME gpio_reg_access_test SOURCES gpio/reg_access_test.c LIBRARIES ${LIBS})
# Can't run this test on FPGA or verilator tops and this test thinks that the GPIO inputs can be
# driven externally
mocha_add_test(NAME gpio_smoketest SOURCES gpio/smoketest.c LIBRARIES ${LIBS} SKIP_VERILATOR SKIP_FPGA)
mocha_add_test(NAME i2c_temperature_sensor_test SOURCES i2c/temperature_sensor_test.c LIBRARIES ${LIBS})
mocha_add_test(NAME i2c_host_tx_rx_test SOURCES i2c/host_tx_rx_test.c LIBRARIES ${LIBS} SKIP_VERILATOR SKIP_FPGA)
mocha_add_test(NAME i2c_device_tx_rx_test SOURCES i2c/device_tx_rx_test.c LIBRARIES ${LIBS} SKIP_VERILATOR SKIP_FPGA)
mocha_add_test(NAME kmac_smoketest SOURCES kmac/smoketest.c LIBRARIES ${LIBS})
mocha_add_test(NAME mailbox_smoketest SOURCES mailbox/smoketest.c LIBRARIES ${LIBS})
mocha_add_test(NAME plic_smoketest SOURCES plic/smoketest.c LIBRARIES ${LIBS})
mocha_add_test(NAME pwrmgr_smoketest SOURCES pwrmgr/smoketest.c LIBRARIES ${LIBS})

# Both test variants share the reference image and digest from this build's bootrom ELF
set(ROM_CTRL_BOOTROM_BIN "${CMAKE_CURRENT_BINARY_DIR}/rom_ctrl_bootrom.bin")
set(ROM_CTRL_BOOTROM_HASH "${CMAKE_CURRENT_BINARY_DIR}/rom_ctrl_bootrom_hash.c")
add_custom_command(
    OUTPUT "${ROM_CTRL_BOOTROM_BIN}" "${ROM_CTRL_BOOTROM_HASH}"
    COMMAND ${CMAKE_OBJCOPY} -O binary "$<TARGET_FILE:bootrom>" "${ROM_CTRL_BOOTROM_BIN}"
    # Use the bootrom's scrambling settings and discard the scrambled image
    COMMAND "${PROJECT_SOURCE_DIR}/../hw/vendor/lowrisc_ip/ip/rom_ctrl/util/scramble_image.py"
      "${PROJECT_SOURCE_DIR}/../hw/data/top.hjson"
      "${PROJECT_SOURCE_DIR}/../hw/data/secrets.testing.hjson"
      base-rom
      "$<TARGET_FILE:bootrom>"
      /dev/null
      "${ROM_CTRL_BOOTROM_HASH}"
    DEPENDS bootrom
    VERBATIM
)
add_custom_target(rom_ctrl_bootrom_ref DEPENDS "${ROM_CTRL_BOOTROM_BIN}" "${ROM_CTRL_BOOTROM_HASH}")
set_source_files_properties(rom_ctrl/bootrom_image.S PROPERTIES
    COMPILE_DEFINITIONS "BOOTROM_BIN=\"${ROM_CTRL_BOOTROM_BIN}\""
    OBJECT_DEPENDS "${ROM_CTRL_BOOTROM_BIN}"
)
mocha_add_test(NAME rom_ctrl_smoketest
    SOURCES rom_ctrl/smoketest.c rom_ctrl/bootrom_image.S "${ROM_CTRL_BOOTROM_HASH}"
    LIBRARIES ${LIBS}
)
add_dependencies(rom_ctrl_smoketest_vanilla rom_ctrl_bootrom_ref)
add_dependencies(rom_ctrl_smoketest_cheri rom_ctrl_bootrom_ref)

mocha_add_test(NAME rstmgr_smoketest SOURCES rstmgr/smoketest.c LIBRARIES ${LIBS})
mocha_add_test(NAME spi_device_smoketest SOURCES spi_device/smoketest.c LIBRARIES ${LIBS})
mocha_add_test(NAME spi_host_sdcard_tests SOURCES spi_host/sdcard_tests.c LIBRARIES ${LIBS})
mocha_add_test(NAME spi_host_smoketest SOURCES spi_host/smoketest.c LIBRARIES ${LIBS} SKIP_VERILATOR SKIP_FPGA)
mocha_add_test(NAME tag_controller_smoketest SOURCES tag_controller/smoketest.c LIBRARIES ${LIBS})
mocha_add_test(NAME tag_controller_tag_test SOURCES tag_controller/tag_test.c LIBRARIES ${LIBS})
mocha_add_test(NAME timer_smoketest SOURCES timer/smoketest.c LIBRARIES ${LIBS})
mocha_add_test(NAME timer_interrupt_test SOURCES timer/interrupt.c LIBRARIES ${LIBS})
mocha_add_test(NAME uart_smoketest SOURCES uart/smoketest.c LIBRARIES ${LIBS})
mocha_add_test(NAME uart_tx_rx_test SOURCES uart/tx_rx_test.c LIBRARIES ${LIBS} SKIP_VERILATOR SKIP_FPGA)
mocha_add_test(NAME isa_atomics SOURCES isa/atomics.c LIBRARIES ${LIBS})

add_subdirectory(opensbi)
