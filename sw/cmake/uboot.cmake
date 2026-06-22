# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Function that builds U-Boot, creating a target with the given output name.
function(mocha_uboot OUTPUT_NAME)
  set(UBOOT_BUILD_NAME ${OUTPUT_NAME}_build)
  # U-Boot repository and tag to use.
  set(UBOOT_REPOSITORY https://github.com/lowrisc/u-boot)
  set(UBOOT_TAG mocha-devel)

  # configure command - load Mocha defconfig file.
  set(CONFIGURE_COMMAND
      make
      lowrisc_mocha_cheri_smode_defconfig
  )

  # build command.
  set(BUILD_COMMAND
      make
      # override CC and LD, as U-boot defaults to using the GNU toolchain.
      "CC=clang -target riscv64-unknown-elf"
      "LD=ld.lld"
  )

  ExternalProject_Add(
      ${UBOOT_BUILD_NAME}
      PREFIX ${UBOOT_BUILD_NAME}
      GIT_REPOSITORY ${UBOOT_REPOSITORY}
      GIT_TAG ${UBOOT_TAG}
      GIT_SHALLOW true
      # U-boot builds in it's own source tree.
      BUILD_IN_SOURCE true
      # make is job server aware.
      BUILD_JOB_SERVER_AWARE true
      CONFIGURE_COMMAND ${CONFIGURE_COMMAND}
      BUILD_COMMAND ${BUILD_COMMAND}
      INSTALL_COMMAND ""
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

  add_executable(${OUTPUT_NAME} IMPORTED GLOBAL)
  set_target_properties(${OUTPUT_NAME} PROPERTIES
      IMPORTED_LOCATION ${CMAKE_CURRENT_BINARY_DIR}/${UBOOT_BUILD_NAME}/src/${UBOOT_BUILD_NAME}/u-boot
    )
  add_dependencies(${OUTPUT_NAME} ${UBOOT_BUILD_NAME})
endfunction()

mocha_uboot(uboot)

mocha_opensbi_with_payload(TARGET uboot)
