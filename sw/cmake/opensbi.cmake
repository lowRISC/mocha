# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Function that builds OpenSBI with a specific payload for Mocha.
function(mocha_opensbi_with_payload PAYLOAD_TARGET)
  # find the target payload file.
  set(PAYLOAD "$<TARGET_FILE:${PAYLOAD_TARGET}>.bin")
  # name of the target OpenSBI build.
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
  # These consist of OpenSBI + the provided payload for the next stage.
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
endfunction()

mocha_opensbi_with_payload(opensbi_test_payload)
