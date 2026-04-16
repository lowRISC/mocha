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
function(mocha_add_executable_artefacts)
    set(one_value_args NAME)
    cmake_parse_arguments(arg "" "${one_value_args}" "" ${ARGN})

    add_custom_command(
        TARGET ${arg_NAME} POST_BUILD
        COMMAND ${CMAKE_OBJDUMP} ${OBJDUMP_FLAGS} "$<TARGET_FILE:${arg_NAME}>"
                > "$<TARGET_FILE:${arg_NAME}>.dump"
        COMMAND ${CMAKE_OBJCOPY} -O binary "$<TARGET_FILE:${arg_NAME}>"
                "$<TARGET_FILE:${arg_NAME}>.bin"
        COMMAND srec_cat "$<TARGET_FILE:${arg_NAME}>.bin" -binary -byte-swap 8
                -o "$<TARGET_FILE:${arg_NAME}>.vmem" -vmem 64
        VERBATIM
    )

    install(TARGETS ${arg_NAME} DESTINATION . COMPONENT ${arg_NAME})
    install(FILES "$<TARGET_FILE:${arg_NAME}>.vmem" DESTINATION . COMPONENT ${arg_NAME})
    install(FILES "$<TARGET_FILE:${arg_NAME}>.bin" DESTINATION . COMPONENT ${arg_NAME})
endfunction()

# for a given executable, add a test that runs the executable
# in the Verilator simulation.
function(mocha_add_verilator_test NAME BOOTROM)
  # Warning: If the BootROM and the test are compiled to the same memory address, the test will 
  # effectively replace the BootROM. Because the BootROM is listed first in the arguments, it is
  # overwritten by the subsequent test image; the simulation will behave as if no BootROM is present
    add_test(
        NAME ${NAME}_sim_verilator
        COMMAND ${PROJECT_SOURCE_DIR}/../util/verilator_runner.sh -E $<TARGET_FILE:${BOOTROM}> -E ${NAME}
    )
endfunction()

function(mocha_add_fpga_test NAME)
    add_test(
        NAME ${NAME}_fpga_genesys2
        COMMAND ${PROJECT_SOURCE_DIR}/../util/fpga_runner.py ${NAME}
    )
endfunction()

set(BOOT_CFG              rom                 bare        ) # Config Name
set(BOOT_CFG_OFFSET       0x8000              0x00        ) # Offset
set(BOOT_CFG_FPGA         YES                 NO          ) # Fpga supported?
set(BOOT_CFG_VERILATOR    NO                  YES         ) # Verilator supported?

set(ARCHS                 vanilla             cheri       ) # Config Name
set(ARCHS_FLAGS           VANILLA_FLAGS       CHERI_FLAGS ) # Flags

# wrapper function to create a CHERI and non-CHERI software test.
# this function automatically handles CHERI libraries by appending "_cheri" to
# the output executable name and all of the libraries it is linked against.
function(mocha_add_test)
    # parse arguments
    set(options FPGA SKIP_VERILATOR)
    set(one_value_args NAME)
    set(multi_value_args SOURCES LIBRARIES)
    cmake_parse_arguments(arg "${options}"
        "${one_value_args}" "${multi_value_args}" ${ARGN})

    foreach(ARCH_NAME FLAGS_VAR IN ZIP_LISTS ARCHS ARCHS_FLAGS)
      set(FLAGS ${${FLAGS_VAR}})

      foreach(CONFIG OFFSET FPGA SIM IN ZIP_LISTS BOOT_CFG BOOT_CFG_OFFSET BOOT_CFG_FPGA BOOT_CFG_VERILATOR)
        set(NAME ${arg_NAME}_${ARCH_NAME}_${CONFIG})
        add_executable(${NAME} ${arg_SOURCES})
        target_compile_options(${NAME} PUBLIC ${FLAGS})
        foreach(LIB ${arg_LIBRARIES})
          target_link_libraries(${NAME} PUBLIC ${LIB}_${ARCH_NAME})
        endforeach()
        target_link_options(${NAME} PUBLIC
          "-Wl,--defsym,BOOT_ROM_OFFSET=${OFFSET}"
          "-T${LDS}" "-L${LDS_DIR}"
        )

        # create artefacts
        mocha_add_executable_artefacts(NAME ${NAME})

        if(SIM AND NOT arg_SKIP_VERILATOR)
          mocha_add_verilator_test(${NAME} bootrom)
        endif()

        if(FPGA AND arg_FPGA)
          mocha_add_fpga_test(${NAME})
        endif()

      endforeach() # BOOT_CFG
    endforeach() # ARCH
endfunction()

# wrapper function to create a CHERI and Vanilla library.
# this function automatically handles CHERI libraries by appending "_cheri" to
# the output library name and all of the libraries it is linked against.
function(mocha_add_library)
    # parse arguments
    set(one_value_args NAME)
    set(multi_value_args SOURCES LIBRARIES)
    cmake_parse_arguments(arg ""
        "${one_value_args}" "${multi_value_args}" ${ARGN})

    foreach(ARCH_NAME FLAGS_VAR IN ZIP_LISTS ARCHS ARCHS_FLAGS)
      set(FLAGS ${${FLAGS_VAR}})
      set(NAME ${arg_NAME}_${ARCH_NAME})

      add_library(${NAME} OBJECT ${arg_SOURCES})
      target_compile_options(${NAME} PUBLIC ${FLAGS})
      target_include_directories(${NAME} PUBLIC "${CMAKE_CURRENT_LIST_DIR}/..")

      get_target_property(VAR ${NAME} INCLUDE_DIRECTORIES)

      foreach(LIB ${arg_LIBRARIES})
        target_link_libraries(${NAME} PUBLIC ${LIB}_${ARCH_NAME})
      endforeach()

    endforeach() # ARCH
endfunction()
