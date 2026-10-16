#!/usr/bin/env -S bash -eu
# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# This should be run from the root of the repository

if [ ! -d "./build/lowrisc_mocha_chip_mocha_genesys2_0" ]; then
    echo "[report_utilisation.sh] ERROR: ./build/lowrisc_mocha_chip_mocha_genesys2_0 directory does not exist"
    echo "Did you:"
    echo "  1. Build the design first?"
    echo "  2. Run util/utilisation_reporting/report_utilisation.sh from the root of the repository?"
    exit 1
fi

mkdir -p scratch
vivado -mode batch -source util/utilisation_reporting/get_reports.tcl ./build/lowrisc_mocha_chip_mocha_genesys2_0/synth-vivado/lowrisc_mocha_chip_mocha_genesys2_0.xpr
uv run python3 util/utilisation_reporting/sunburst.py scratch/util_full.txt
