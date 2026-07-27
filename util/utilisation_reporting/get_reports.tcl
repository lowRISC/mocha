# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Open the implementated design
open_run impl_1

# Report utilisation and dump to a file
report_utilization -hierarchical -hierarchical_depth 0 -file scratch/util_full.txt
# depth of 0 is interpreted as infinite

# If you're reading this file, you may be interested in some other options:

# Generate a spreadsheet report instead of text file (only works in GUI mode):
#report_utilization -hierarchical -spreadsheet_depth 0 -spreadsheet_file util.xlsx
# Generate a hierarchical report with less depth (useful for large designs):
#report_utilization -hierarchical -spreadsheet_depth 3 -spreadsheet_file util_depth3.xlsx
