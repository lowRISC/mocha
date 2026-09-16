# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import plotly.graph_objects as go
from parse_report import Node, parse_utilisation_report


def name2id(name: str) -> str:
    """Convert a node name to a unique ID for use in the sunburst chart."""
    replacements = {
        "[": "_",
        "]": "_",
        "(": "_",
        ")": "_",
        " ": "_",
        ".": "_",
    }
    for old, new in replacements.items():
        name = name.replace(old, new)
    return name


def build_sunburst_arrays(root: Node, value_getter=lambda n: n.util.total_luts):
    """Plotly expects a sunburst chart to be defined by four parallel arrays: ids, labels, parents,
    and values. This function walks the Node tree and builds those arrays."""
    ids = []
    labels = []
    parents = []
    values = []

    def walk(node: Node, path: str):
        node_id = path

        # Recurse into children (and tally their utilisation as we go)
        child_util_sum = 0
        for child in node.children:
            child_path = f"{node_id}.{name2id(child.name)}"
            child_util_sum += walk(child, child_path)

        # Add this node to the arrays too
        ids.append(node_id)
        labels.append(node.name)
        this_util = max(
            value_getter(node), child_util_sum
        )
        # if the node's own utilisation is less than the sum of its children, use the sum of its
        # children instead. Vivado will occasionally have a parent equal to less than the sum of its
        # children due to cross-boundary optimisation. We will take the sum of the children in that
        # case, otherwise we can't display it
        values.append(this_util)

        # Root has no parent
        if "." in node_id:
            parents.append(node_id.rsplit(".", 1)[0])
        else:
            parents.append("")  # Plotly root marker

        return this_util  # return the total utilisation as this will be useful for the parent

    walk(root, root.name)
    return ids, labels, parents, values


def ff_getter(node: Node):
    """Return the number of flip-flops in this node's own reported utilisation."""
    return node.util.ffs


def lut_getter(node: Node):
    """Return the number of LUT's in this node's own reported utilisation."""
    return node.util.total_luts


def ff_plus_lut_getter(node: Node):
    """Return the number of flip-flops and LUT's in this node's own reported utilisation."""
    return node.util.ffs + node.util.total_luts


def bram_getter(node: Node):
    """Return the number of BRAM18-equivalent blocks in this node's own reported utilisation."""
    return node.util.ramb18 + node.util.ramb36 * 2


def generate_sunburst(root, value_getter, outfile, title):
    """
    Given the root of a Node tree, generate a sunburst plot and output to a HTML file.
    The value_getter function is used to extract the value to be plotted from each node
    (e.g. number of LUTs, number of flip-flops, etc.)
    """
    raw_data = build_sunburst_arrays(root, value_getter=value_getter)
    ids, labels, parents, values = raw_data

    # depth visible at any one time, to avoid clutter. Users can zoom in to see more detail
    plot_maxdepth = 4

    # "total" means the value of a parent node INCLUDES the values of its children. Usually it the
    # parent will be slightly larger than the sum of its children, but note that occasionally a
    # parent will actually be smaller than the sum of its children due to Vivado's cross-boundary
    # optimisation; Plotly will work around this if it occurs
    branch_value_style = "total"

    # Create the sunburst plot
    fig = go.Figure(
        go.Sunburst(
            ids=ids,
            labels=labels,
            parents=parents,
            values=values,
            branchvalues=branch_value_style,
            maxdepth=plot_maxdepth,
        )
    )

    # Set some behaviours for interacting with it
    fig.update_traces(
        marker={"colors":None},  # force Plotly to regenerate colours
        leaf={"opacity":1},  # ensures leaves get distinct colours
    )
    fig.update_layout(
        title=title,
        title_x=0.5,
        title_font_size=22,
        title_font_color="darkblue"
    )

    fig.write_html(outfile)


if __name__ == "__main__":
    # If we are run as a script, take the first command line argument as a path
    # to a Vivado `report_utilization -hierarchical` text report, parse it, and
    # generate two sunburst plots: one for BRAM utilisation and one for FF+LUT
    # utilisation.
    import sys

    if len(sys.argv) < 2:
        print("Usage: python sunburst.py <path_to_vivado_report_utilisation.txt>")
        sys.exit(1)

    tree_root = parse_utilisation_report(sys.argv[1])

    generate_sunburst(
        tree_root,
        value_getter=bram_getter,
        outfile="bram_util.html",
        title="BRAM Utilisation"
    )
    generate_sunburst(
        tree_root,
        value_getter=ff_plus_lut_getter,
        outfile="ff_lut_util.html",
        title="FF+LUT Utilisation"
    )

    print("Sunburst plots generated: bram_util.html and ff_lut_util.html")
