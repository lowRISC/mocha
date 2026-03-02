## Copyright lowRISC contributors (COSMIC project).
## Licensed under the Apache License, Version 2.0, see LICENSE for details.
## SPDX-License-Identifier: Apache-2.0

## Do not wait for DCI matching to complete during startup
## Works around done=0 error when loading with openFPGALoader
set_property BITSTREAM.STARTUP.MATCH_CYCLE NoWait [current_design];
