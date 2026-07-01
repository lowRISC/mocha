# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Function that builds U-Boot, creating a target with the given output name.
function(mocha_uboot UBOOT_NAME)
  # U-Boot repository and tag to use.
  set(UBOOT_REPOSITORY https://github.com/lowRISC/u-boot)
  set(UBOOT_TAG mocha-mvp2)

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
  
  # install command - copy the built U-Boot binary to the root of the external project directory.
  set(INSTALL_COMMAND
      cp u-boot <INSTALL_DIR>
  )

  ExternalProject_Add(
      ${UBOOT_NAME}
      PREFIX ${UBOOT_NAME}
      GIT_REPOSITORY ${UBOOT_REPOSITORY}
      GIT_TAG ${UBOOT_TAG}
      GIT_SHALLOW true
      # U-boot builds in it's own source tree.
      BUILD_IN_SOURCE true
      # make is job server aware.
      BUILD_JOB_SERVER_AWARE true
      CONFIGURE_COMMAND ${CONFIGURE_COMMAND}
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
      ${CMAKE_CURRENT_BINARY_DIR}/${UBOOT_NAME}/u-boot
      DESTINATION .
      COMPONENT boot
  )
endfunction()

mocha_uboot(uboot)
