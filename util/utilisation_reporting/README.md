<!--
# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
-->

Generates:
- a text report of FPGA resource utilisation, organised hierarchically
- a HTML sunburst diagram showing BRAM utilisation by instance
- a HTML sunburst diagram showing LUT+FF utilisation by instance

The sunburst diagrams are interactive -- click on a wedge to explore its children.

To generate, return to the repository root and run:
```
./util/utilisation_reporting/report_utilisation.sh
```
Expect this to take a minute or two as it will need to open the design in Vivado.
