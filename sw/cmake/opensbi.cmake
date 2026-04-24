# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Function that builds OpenSBI with a specific payload for Mocha.
function(mocha_opensbi_with_payload PAYLOAD_TARGET)
  # find the target payload file.
  set(PAYLOAD "$<TARGET_FILE:${PAYLOAD_TARGET}>.bin")
  #
  set(NAME opensbi_with_${PAYLOAD_TARGET})

  # OpenSBI repository and tag to use.
  set(OPENSBI_REPOSITORY https://github.com/lowrisc/opensbi)
  set(OPENSBI_TAG mocha-devel)

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
      # Build a 'payload' firmware.
      FW_PAYLOAD=y
      FW_JUMP=n
      # Build with the given payload.
      FW_PAYLOAD_PATH=${PAYLOAD}
      # Disable position-independent code and link to DRAM base,
      # as loading position-independent executables is not supported by
      # our Verilator ELF loader.
      FW_PIC=n
      FW_TEXT_START=0x80000000
      # 0x2 bit = build with runtime debug printing.
      FW_OPTIONS=0x2
  )

  # Built firmware binaries to copy into the root of the external project directory.
  set(FIRMWARES
      build/platform/generic/firmware/fw_payload.elf
      build/platform/generic/firmware/fw_payload.bin
  )

  # install command - copy the firmware binaries to the root of the external project directory.
  set(INSTALL_COMMAND
      cp ${FIRMWARES} <INSTALL_DIR>
  )

  ExternalProject_Add(
      ${NAME} PREFIX ${NAME}
      GIT_REPOSITORY ${OPENSBI_REPOSITORY}
      GIT_TAG ${OPENSBI_TAG}
      # OpenSBI builds in its own 'build' sub-directory.
      BUILD_IN_SOURCE true
      # make is job server aware.
      BUILD_JOB_SERVER_AWARE true
      CONFIGURE_COMMAND "" # no configure step needed, do nothing here.
      BUILD_COMMAND ${BUILD_COMMAND}
      INSTALL_COMMAND ${INSTALL_COMMAND}
      # depend on the given payload target.
      DEPENDS ${PAYLOAD_TARGET}
  )
endfunction()

# Like mocha_opensbi_with_payload, but also adds a test for Simulation
# and FPGA environments.
function(mocha_opensbi_with_payload_test PAYLOAD_TARGET)
  # name of the target OpenSBI build.
  set(NAME opensbi_with_${PAYLOAD_TARGET})

  mocha_opensbi_with_payload(${PAYLOAD_TARGET})

  add_test(
      NAME ${NAME}_sim_verilator
      # TODO: This is a long test. Bypass the Verilator runner for now,
      # as that has a pre-defined timeout that we should get rid of.
      # TODO: Verilator test function that automatically supplies the
      # boot ROM too.
      COMMAND
        ${PROJECT_SOURCE_DIR}/../build/lowrisc_mocha_top_chip_verilator_0/sim-verilator/Vtop_chip_verilator
        -E ${NAME}/fw_payload.elf
        -E $<TARGET_FILE:bootrom>
  )
  set_property(TEST ${NAME}_sim_verilator PROPERTY TIMEOUT 7200)
  set_property(TEST ${NAME}_sim_verilator PROPERTY LABELS opensbi verilator slow)

  add_test(
      NAME ${NAME}_fpga_genesys2
      COMMAND ${PROJECT_SOURCE_DIR}/../util/fpga_runner.py ${NAME}/fw_payload.elf
  )
  set_property(TEST ${NAME}_fpga_genesys2 PROPERTY LABELS opensbi fpga)
endfunction()

mocha_opensbi_with_payload_test(opensbi_test_payload)
