# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

from dataclasses import dataclass, field
from pathlib import Path
from typing import NamedTuple


class Utilisation(NamedTuple):
    total_luts: int
    logic_luts: int
    lutrams: int
    srls: int
    ffs: int
    ramb36: int
    ramb18: int
    dsp: int


@dataclass
class Node:
    name: str  # instance name, e.g. "u_ddr3_mig" or "(u_ddr3_mig)" for self-logic
    module: str  # module/cell type, e.g. "u_xlnx_mig_7_ddr3"
    util: Utilisation  # this row's own reported utilisation
    children: list = field(default_factory=list)


def extract_utilisation_table(path: str) -> str:
    """Thin wrapper that finds the 'utilisation by Hierarchy' table in a raw Vivado
    report_utilization file and returns just its data rows, stripping the file header,
    table of contents, and footnotes."""
    with Path(path).open(encoding="utf8") as f:
        lines = f.readlines()
    header = next(i for i, j in enumerate(lines) if "Instance" in j and "Module" in j)
    data_start = header + 2  # skip the header row and the border beneath it
    data_end = next(i for i in range(data_start, len(lines)) if lines[i].startswith("+"))
    return "".join(lines[data_start:data_end])


def parse_utilisation_report(path: str) -> Node:
    """Parse a Vivado `report_utilization -hierarchical` text report into a Node tree."""
    rows = []
    for line in extract_utilisation_table(path).splitlines():
        parts = line.split("|")[1:-1]
        # Vivado should emit instance name, module name, and eight resource-count columns:
        if len(parts) != len(Utilisation._fields) + 2:
            continue
        instance, module, *nums = parts
        try:
            nums = [int(n.strip()) for n in nums]
        except ValueError:
            continue  # stray blank/border line
        depth = (
            len(instance) - len(instance.lstrip(" "))
        ) // 2  # each 2 leading spaces is one level of hierarchical depth
        rows.append((depth, instance.strip(), module.strip(), Utilisation(*nums)))

    root = None
    stack = []  # list of (depth, node), innermost last
    for depth, name, module, util in rows:
        if "(" in name:
            continue  # skip self-logic rows, which are redundant with their parent
        node = Node(name, module, util)
        while stack and stack[-1][0] >= depth:
            stack.pop()
        if stack:
            stack[-1][1].children.append(node)
        else:
            root = node
        stack.append((depth, node))
    return root
