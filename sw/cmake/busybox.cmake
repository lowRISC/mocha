# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

function(mocha_busybox OUTPUT_NAME)
  set(BUSYBOX_BUILD_NAME ${OUTPUT_NAME}_build)
  # Busybox repository and tag to use.
  set(BUSYBOX_REPOSITORY https://github.com/lowRISC/busybox)
  set(BUSYBOX_TAG mocha-mvp2)

  # configure command - load Mocha defconfig file.
  set(CONFIGURE_COMMAND
      make
      mocha_defconfig
  )

  # Clang flags.
  set(FLAGS
      " \
      -target riscv64-linux-musl \
      -march=rv64imaczcherihybrid_zcherilevels \
      -mabi=l64pc128 \
      -mno-relax \
      -static \
      -isystem $ENV{LIBC_PURECAP_INCLUDE} \
      -isystem $ENV{SYSROOT_PURECAP} \
      -L $ENV{LIBC_PURECAP_LIB} \
      -B $ENV{LIBC_PURECAP_LIB} \
      -L $ENV{COMPILER_RT_PURECAP} \
      -B $ENV{COMPILER_RT_PURECAP} \
      -Xclang -target-feature -Xclang +cheri-bounded-vararg \
      -Xclang -target-feature -Xclang +cheri-bounded-memarg-caller \
      -Xclang -target-feature -Xclang +cheri-bounded-memarg-callee \
      "
  )

  # build command.
  set(BUILD_COMMAND
      make
      ARCH=riscv
      "CC=clang ${FLAGS}"
      HOSTCC=gcc
      "LD=ld.lld"
      "CFLAGS_busybox=--unwindlib=none ${FLAGS} -fuse-ld=lld"
  )

  # Busybox built images.
  set(BUSYBOX_ARTEFACTS
      busybox
  )

  # install command - copy busybox images to the root of the external project directory.
  set(INSTALL_COMMAND
      cp ${BUSYBOX_ARTEFACTS} <INSTALL_DIR>
  )

  ExternalProject_Add(
      ${BUSYBOX_BUILD_NAME}
      PREFIX ${BUSYBOX_BUILD_NAME}
      GIT_REPOSITORY ${BUSYBOX_REPOSITORY}
      GIT_TAG ${BUSYBOX_TAG}
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

  add_executable(${OUTPUT_NAME} IMPORTED GLOBAL)
  set_target_properties(${OUTPUT_NAME} PROPERTIES
      IMPORTED_LOCATION ${CMAKE_CURRENT_BINARY_DIR}/${BUSYBOX_BUILD_NAME}/src/${BUSYBOX_BUILD_NAME}/busybox
  )
endfunction()

mocha_busybox(busybox)
