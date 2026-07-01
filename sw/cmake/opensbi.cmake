# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Function that builds OpenSBI for Mocha.
function(mocha_opensbi OPENSBI_NAME)
  # OpenSBI repository and tag to use.
  set(OPENSBI_REPOSITORY https://github.com/lowRISC/opensbi)
  set(OPENSBI_TAG mocha-mvp2)

  # build command - run make with build options.
  set(BUILD_COMMAND
      make
      # Use CHERI LLVM.
      LLVM=1
      # ISA options.
      PLATFORM_RISCV_XLEN=64
      PLATFORM_RISCV_ISA=rv64imac_zcherihybrid
      PLATFORM_RISCV_ABI=l64pc128
      # Build for the 'generic' platform, which uses devicetree data.
      PLATFORM=generic
      # Use the Mocha defconfig file.
      PLATFORM_DEFCONFIG=mocha_defconfig
      # Build a 'jump' firmware.
      FW_JUMP=y
      FW_PAYLOAD=n
      # Disable position-independent code and link to DRAM base,
      # as loading position-independent executables is not supported by
      # our Verilator ELF loader.
      FW_PIC=n
      FW_TEXT_START=0x80000000
      # 0x2 bit = build with runtime debug printing.
      FW_OPTIONS=0x2
  )

  # Built firmware binary to copy into the root of the external project directory.
  # This consists of OpenSBI + the provided payload for the next stage.
  set(FIRMWARE
      build/platform/generic/firmware/fw_jump.elf
  )

  # install command - copy the firmware binaries to the root of the external project directory.
  set(INSTALL_COMMAND
      cp ${FIRMWARE} <INSTALL_DIR>/${OPENSBI_NAME}_fw_jump.elf
  )

  ExternalProject_Add(
      ${OPENSBI_NAME} PREFIX ${OPENSBI_NAME}
      GIT_REPOSITORY ${OPENSBI_REPOSITORY}
      GIT_TAG ${OPENSBI_TAG}
      # OpenSBI builds in its own 'build' sub-directory.
      BUILD_IN_SOURCE true
      # make is job server aware.
      BUILD_JOB_SERVER_AWARE true
      CONFIGURE_COMMAND "" # no configure step needed, do nothing here.
      BUILD_COMMAND ${BUILD_COMMAND}
      INSTALL_COMMAND ${INSTALL_COMMAND}
      # suppress output from stdout.
      LOG_DOWNLOAD true
      LOG_UPDATE true
      LOG_PATCH true
      LOG_CONFIGURE true
      LOG_BUILD true
      LOG_INSTALL true
      LOG_MERGED_STDOUTERR true
      LOG_OUTPUT_ON_FAILURE true
  )

  install(FILES
      ${CMAKE_CURRENT_BINARY_DIR}/${OPENSBI_NAME}/${OPENSBI_NAME}_fw_jump.elf
      DESTINATION .
      COMPONENT boot
  )
endfunction()

function(mocha_opensbi_test OPENSBI_NAME TARGET_NAME)

  add_dependencies(${TARGET_NAME} ${OPENSBI_NAME})
  set(TEST_NAME opensbi_with_${TARGET_NAME})

  add_test(
      NAME ${TEST_NAME}_sim_verilator
      COMMAND ${PROJECT_SOURCE_DIR}/../util/verilator_runner.sh
          -r $<TARGET_FILE:bootrom>_scrambled.vmem
          -E ${OPENSBI_NAME}/${OPENSBI_NAME}_fw_jump.elf
          -E $<TARGET_FILE:${TARGET_NAME}>
  )

  add_test(
      NAME ${TEST_NAME}_fpga_genesys2
      COMMAND ${PROJECT_SOURCE_DIR}/../util/fpga_runner.py test
          -e ${OPENSBI_NAME}/${OPENSBI_NAME}_fw_jump.elf
          -e $<TARGET_FILE:${TARGET_NAME}>
  )

  set_property(TEST ${TEST_NAME}_sim_verilator PROPERTY TIMEOUT 7200)
  set_property(TEST ${TEST_NAME}_sim_verilator PROPERTY LABELS opensbi verilator slow)
  set_property(TEST ${TEST_NAME}_fpga_genesys2 PROPERTY TIMEOUT 60)
  set_property(TEST ${TEST_NAME}_fpga_genesys2 PROPERTY LABELS opensbi fpga)
endfunction()

mocha_opensbi(opensbi)

mocha_opensbi_test(opensbi opensbi_test_payload)
