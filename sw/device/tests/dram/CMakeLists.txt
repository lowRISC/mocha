# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# This DRAM test is to test loading a binary into DRAM in Verilator,
# before we have general support for running tests from DRAM.
# For this test, we build a version of the test framework test linked at DRAM
# which we load alongside the test binary. The test binary just jumps into DRAM.

# TODO: This should be generalised to all tests once we have the ability to load
# DRAM in all environments (FPGA, DV).

set(LIBS hal runtime startup test_framework)

# Test framework smoketest.
add_executable(test_framework_test_vanilla_dram ../test_framework/smoketest.c)
target_compile_options(test_framework_test_vanilla_dram PUBLIC ${VANILLA_FLAGS})
foreach(LIB ${LIBS})
    target_link_libraries(test_framework_test_vanilla_dram PUBLIC ${LIB}_vanilla)
    target_include_directories(test_framework_test_vanilla_dram PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/../../lib")
endforeach()
target_link_options(
    test_framework_test_vanilla_dram PUBLIC
    # Workaround: This address doesn't matter as we don't use system reset here,
    # but it needs to be addressible by the medany code model.
    "-Wl,--defsym,BOOT_ROM_OFFSET=0x80000000"
    "-T" "dram_test.ld"
    "-L" ${LDS_DIR}
)

# Atomics ISA test.
add_executable(atomics_vanilla_dram ../isa/atomics.c)
target_compile_options(atomics_vanilla_dram PUBLIC ${VANILLA_FLAGS})
foreach(LIB ${LIBS})
    target_link_libraries(atomics_vanilla_dram PUBLIC ${LIB}_vanilla)
    target_include_directories(atomics_vanilla_dram PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/../../lib")
endforeach()
target_link_options(
    atomics_vanilla_dram PUBLIC
    # Workaround: This address doesn't matter as we don't use system reset here,
    # but it needs to be addressible by the medany code model.
    "-Wl,--defsym,BOOT_ROM_OFFSET=0x80000000"
    "-T" "dram_test.ld"
    "-L" ${LDS_DIR}
)

add_executable(dram_test_rom ../dram/dram_test_rom.c)
target_compile_options(dram_test_rom PUBLIC ${VANILLA_FLAGS})
foreach(LIB ${LIBS})
    target_link_libraries(dram_test_rom PUBLIC ${LIB}_vanilla)
    target_include_directories(dram_test_rom PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/../../lib")
endforeach()
target_link_options(
    dram_test_rom PUBLIC
    "-Wl,--defsym,BOOT_ROM_OFFSET=0x00"
    "-T" "${LDS}"
    "-L" ${LDS_DIR}
)

add_test(
    NAME dram_load_test_sim_verilator
    COMMAND ${PROJECT_SOURCE_DIR}/../util/verilator_runner.sh -E dram_test_rom -E test_framework_test_vanilla_dram
)

add_test(
    NAME dram_atomics_test_sim_verilator
    COMMAND ${PROJECT_SOURCE_DIR}/../util/verilator_runner.sh -E dram_test_rom -E atomics_vanilla_dram
)
