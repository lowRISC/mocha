#!/usr/bin/env bash
# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

rm -r hw/top_chip/ip_autogen/rv_plic
hw/vendor/lowrisc_ip/util/ipgen.py generate \
  -C hw/vendor/lowrisc_ip/ip_templates/rv_plic/ \
  -c hw/top_chip/data/rv_plic_cfg.hjson \
  -o hw/top_chip/ip_autogen/rv_plic && \
# Remove documentation which do not have license headers \
rm -r hw/top_chip/ip_autogen/rv_plic/doc hw/top_chip/ip_autogen/rv_plic/README.md
