#!/usr/bin/env -S bash -eux
# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

find hw/top_chip/rtl hw/top_chip/dv -name "*.sv" | \
  xargs verible-verilog-format \
  --inplace \
  --column_limit=120 \
  --indentation_spaces=2 \
  --wrap_spaces=2 \
  --assignment_statement_alignment=align \
  --case_items_alignment=align \
  --class_member_variable_alignment=preserve \
  --distribution_items_alignment=align \
  --enum_assignment_statement_alignment=align \
  --formal_parameters_alignment=align \
  --module_net_variable_alignment=align \
  --named_parameter_alignment=align \
  --named_port_alignment=align \
  --port_declarations_alignment=align \
  --port_declarations_right_align_packed_dimensions=true \
  --port_declarations_right_align_unpacked_dimensions=true \
  --struct_union_members_alignment=align
