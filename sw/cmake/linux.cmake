# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

function(mocha_linux OUTPUT_NAME)
  set(LINUX_BUILD_NAME ${OUTPUT_NAME})
  # Linux repository and tag to use.
  set(LINUX_REPOSITORY https://github.com/lowRISC/linux)
  set(LINUX_TAG mocha-mvp2)

  # configure command - load Mocha defconfig file.
  set(CONFIGURE_COMMAND
      make
      # set ARCH so that we look in arch/riscv/configs.
      ARCH=riscv
      # enable LLVM.
      LLVM=1
      # Override the host compiler.
      HOSTCC=gcc
      lowrisc_cheri_mocha_defconfig
  )

  # build command.
  set(BUILD_COMMAND
      make
      ARCH=riscv
      LLVM=1
      # Override the host compiler.
      HOSTCC=gcc
  )

  # Built kernel image.
  set(LINUX_IMAGE
      arch/riscv/boot/Image
  )

  # install command - copy the kernel image to the root of the external project directory.
  set(INSTALL_COMMAND
      cp ${LINUX_IMAGE} <INSTALL_DIR>/linux_image
  )

  ExternalProject_Add(
      ${LINUX_BUILD_NAME}
      PREFIX ${LINUX_BUILD_NAME}
      GIT_REPOSITORY ${LINUX_REPOSITORY}
      GIT_TAG ${LINUX_TAG}
      GIT_SHALLOW true
      # Linux builds in it's own source tree.
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
      ${CMAKE_CURRENT_BINARY_DIR}/${LINUX_BUILD_NAME}/linux_image
      DESTINATION .
      COMPONENT boot
  )
endfunction()

mocha_linux(linux)
