# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set(
    OBJDUMP_FLAGS
    --disassemble
    --demangle
    --source
    --file-headers
    --section-headers
)

# for a given executable, create a raw binary (.bin), verilog memory (.vmem),
# and disassembly output for debugging (.dump).
macro(mocha_add_executable_artefacts NAME)
    add_custom_command(
        TARGET ${NAME} POST_BUILD
        COMMAND ${CMAKE_OBJDUMP} ${OBJDUMP_FLAGS} "$<TARGET_FILE:${NAME}>"
                > "$<TARGET_FILE:${NAME}>.dump"
        COMMAND ${CMAKE_OBJCOPY} -O binary "$<TARGET_FILE:${NAME}>"
                "$<TARGET_FILE:${NAME}>.bin"
        COMMAND srec_cat "$<TARGET_FILE:${NAME}>.bin" -binary -byte-swap 8
                -o "$<TARGET_FILE:${NAME}>.vmem" -vmem 64
        VERBATIM
    )

    install(TARGETS ${NAME} DESTINATION . COMPONENT ${NAME})
    install(FILES "$<TARGET_FILE:${NAME}>.vmem" DESTINATION . COMPONENT ${NAME})
endmacro()

# for a given executable, add a test that runs the executable
# in the Verilator simulation.
macro(mocha_add_verilator_test NAME)
    add_test(
        NAME ${NAME}_sim_verilator
        COMMAND ${PROJECT_SOURCE_DIR}/../util/verilator_runner.sh ${NAME}
    )
endmacro()

# wrapper macro to create a CHERI and non-CHERI software test.
# this macro automatically handles CHERI libraries by appending "_cheri" to
# the output executable name and all of the libraries it is linked against.
macro(mocha_add_test)
    # parse arguments
    set(one_value_args NAME)
    set(multi_value_args SOURCES LIBRARIES)
    cmake_parse_arguments(arg ""
        "${one_value_args}" "${multi_value_args}" ${ARGN})

    # create non-CHERI executable from SOURCES and LIBRARIES.
    add_executable(${arg_NAME} ${arg_SOURCES})
    target_compile_options(${arg_NAME} PUBLIC ${NON_CHERI_FLAGS})
    foreach(LIB ${arg_LIBRARIES})
        target_link_libraries(${arg_NAME} PUBLIC ${LIB})
    endforeach()
    target_link_options(${arg_NAME} PUBLIC "-T${LDS}" "-L${LDS_DIR}")
    # create artefacts and verilator test
    mocha_add_executable_artefacts(${arg_NAME})
    mocha_add_verilator_test(${arg_NAME})
    # do the same for the CHERI executable, but append "_cheri" to the output
    # exectuable name and all of the libraries it is being linked against.
    add_executable(${arg_NAME}_cheri ${arg_SOURCES})
    target_compile_options(${arg_NAME}_cheri PUBLIC ${CHERI_FLAGS})
    foreach(LIB ${arg_LIBRARIES})
        target_link_libraries(${arg_NAME}_cheri PUBLIC ${LIB}_cheri)
    endforeach()
    target_link_options(${arg_NAME}_cheri PUBLIC "-T${LDS}" "-L${LDS_DIR}")
    # create artefacts and verilator test
    mocha_add_executable_artefacts(${arg_NAME}_cheri)
    mocha_add_verilator_test(${arg_NAME}_cheri)
endmacro()

# wrapper macro to create a CHERI and non-CHERI library.
# this macro automatically handles CHERI libraries by appending "_cheri" to
# the output library name and all of the libraries it is linked against.
macro(mocha_add_library)
    # parse arguments
    set(one_value_args NAME)
    set(multi_value_args SOURCES LIBRARIES)
    cmake_parse_arguments(arg ""
        "${one_value_args}" "${multi_value_args}" ${ARGN})

    # create non-CHERI library from SOURCES and LIBRARIES.
    add_library(${arg_NAME} OBJECT ${arg_SOURCES})
    target_compile_options(${arg_NAME} PUBLIC ${NON_CHERI_FLAGS})
    target_include_directories(${arg_NAME} PUBLIC "..")
    foreach(LIB ${arg_LIBRARIES})
        target_link_libraries(${arg_NAME} PUBLIC ${LIB})
    endforeach()
    # do the same for the CHERI library, but append "_cheri" to the output
    # library name and all of the libraries it is being linked against.
    add_library(${arg_NAME}_cheri OBJECT ${arg_SOURCES})
    target_compile_options(${arg_NAME}_cheri PUBLIC ${CHERI_FLAGS})
    target_include_directories(${arg_NAME}_cheri PUBLIC "..")
    foreach(LIB ${arg_LIBRARIES})
        target_link_libraries(${arg_NAME}_cheri PUBLIC ${LIB}_cheri)
    endforeach()
endmacro()

add_subdirectory(bootrom)
add_subdirectory(lib)
add_subdirectory(tests)
add_subdirectory(examples/hello_world)
add_subdirectory(examples/tag_check)
