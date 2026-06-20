# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Linux root filesystem.

function(mocha_rootfs)
  add_custom_command(
      OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/rootfs_uboot_image
      COMMAND
        ${PROJECT_SOURCE_DIR}/../util/make_rootfs.py ${CMAKE_CURRENT_BINARY_DIR}
          --include-tree ${PROJECT_SOURCE_DIR}/device/rootfs/root
          --busybox $<TARGET_FILE:busybox>
      DEPENDS busybox_build
    )

  add_custom_target(mocha_rootfs ALL
      DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/rootfs_uboot_image)
endfunction()

mocha_rootfs()
