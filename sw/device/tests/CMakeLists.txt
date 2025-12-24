# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

macro(add_verilator_test NAME)
    target_link_libraries(${NAME} test_framework)
    add_test(NAME ${NAME}_sim_verilator COMMAND ${PROJECT_SOURCE_DIR}/../util/verilator_runner.sh ${NAME})
endmacro()


set(NAME test_framework_test)
add_executable(${NAME})
target_link_libraries(${NAME} hal startup)
add_exe_artefacts(${NAME})
add_verilator_test(${NAME})


set(NAME uart_smoketest)
add_executable(${NAME} uart/smoketest.c)
target_compile_options(${NAME} PUBLIC ${NON_CHERI_FLAGS})
target_link_libraries(${NAME} hal startup)
add_exe_artefacts(${NAME})
add_verilator_test(${NAME})


set(NAME timer_smoketest)
add_executable(${NAME} timer/smoketest.c)
target_compile_options(${NAME} PUBLIC ${NON_CHERI_FLAGS})
target_link_libraries(${NAME} hal startup)
add_exe_artefacts(${NAME})
add_verilator_test(${NAME})
