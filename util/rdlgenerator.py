#!/usr/bin/env python
# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import json
import sys
from pathlib import Path
from typing import TextIO

import jinja2
import svgwrite


def human_size(num, suffix="B"):
    for unit in ["", "ki", "Mi", "Gi", "Ti", "Pi"]:
        if abs(num) < 1024:
            return f"{num:3.1f} {unit}{suffix}"
        num /= 1024


def gen_from_template(input_file: Path, out_file: Path, template: str, comment_scape: str = "//"):
    """Process a template and generate a file."""

    print(f"Loading file: {input_file}...")
    with input_file.open("r") as f:
        rdljson = json.load(f)

    for device in rdljson["devices"]:
        device["human_size"] = human_size(device["size"])

    template = jinja2.Template(template)

    with out_file.open("a") as f:
        f.write(template.render(rdljson))
        f.write("\n")

    print(f"Successfully generated {out_file}")


def get_command_line() -> str:
    args = []
    for item in sys.argv:
        if Path(item).exists():
            args.append(str(Path(item).resolve().relative_to(Path.cwd())))
        else:
            args.append(item)
    return " ".join(args)


# REUSE-IgnoreStart
LICENSE_HEADER = """Copyright lowRISC contributors (COSMIC project).
Licensed under the Apache License, Version 2.0, see LICENSE for details.
SPDX-License-Identifier: Apache-2.0
"""
# REUSE-IgnoreEnd


def emit_file_header(file: TextIO, comment_open: str = "", comment_close: str = "") -> None:
    """Emit a file header consisting of the project's license header and a line showing
    what command was invoked to generate it, wrapped in comments."""
    for line in LICENSE_HEADER.splitlines():
        file.write(f"{comment_open}{line}{comment_close}\n")
    file.write(f"{comment_open}Auto-generated: '{get_command_line()}'{comment_close}\n")


LD_TEMPLATE = """
MEMORY {
{%- for device in devices %}
  {%- set base_addr = device.offset if device.offset else device.offsets[0] %}
    {%- if device.type == "mem" %}
        {%- set name = device.name %}
        {%- set addr = base_addr %}
        {%- set size = device.size %}
        {%- set hsize = device.human_size %}
    {{"{:<10}: ORIGIN = {:#010x}, LENGTH = {:#010x} /* {:>6} */".format(name, addr, size, hsize)}}
    {%- endif %}
{%- endfor %}
}
"""


def gen_linker_script(args) -> None:
    """Generate a linker file with the memory map."""

    input_file = Path(args.input_file)
    out_file = Path(args.out_file)

    with out_file.open("w") as f:
        emit_file_header(f, comment_open="/* ", comment_close=" */")
    gen_from_template(input_file, out_file, LD_TEMPLATE)


def gen_memory_map(args) -> None:
    """Generate a svg file with the memory map."""

    input_file = Path(args.input_file)
    out_file = Path(args.out_file)

    print(f"Loading file: {input_file}...")
    with input_file.open("r") as f:
        rdljson = json.load(f)

    cell_w = 160
    cell_h = 30
    rows_n = len(rdljson["devices"]) + 1
    cols = 4

    dwg = svgwrite.Drawing(out_file, size=(cell_w * cols, cell_h * rows_n))
    font = {"font_size": 14, "font_family": "monospace"}

    # Header
    header = ["Base address", "Top address", "Reserved", "Function"]
    for c, h in enumerate(header):
        x = c * cell_w
        dwg.add(dwg.rect((x, 0), (cell_w, cell_h), fill="black", stroke="white"))
        dwg.add(dwg.text(h, insert=(x + 6, 20), **font, fill="white"))

    # Rows
    for r, device in enumerate(rdljson["devices"], start=1):
        base_addr = device["offset"] if "offset" in device else device["offsets"][0]
        end_addr = base_addr + device["size"] - 1
        size = human_size(device["size"])
        line = [f"{base_addr:#010x}", f"{end_addr:#010x}", size, device["name"]]
        for c, cell in enumerate(line):
            x = c * cell_w
            y = r * cell_h
            dwg.add(dwg.rect((x, y), (cell_w, cell_h), fill="white", stroke="black"))
            dwg.add(dwg.text(cell, insert=(x + 6, y + 20), **font))

    dwg.save()


def check_register_rdl(devices: list) -> None:
    """
    Check some properties of the register interface json that we rely on in the code generator.
    """
    for device in devices:
        device_name = device["name"].lower()
        registers = device["interfaces"][0]["regs"]
        for reg in registers:
            register_name = reg["name"].lower()
            # check that all registers are 32-bits wide
            if reg["width"] != 32:
                raise ValueError(
                    f"Register '{register_name}' in device '{device_name}' is not 32-bits wide"
                )
            # check that all register offsets are naturally-aligned
            offset_string = reg["offsets"]
            for offset in offset_string:
                if offset % 4 != 0:
                    raise ValueError(
                        f"Register '{register_name}' in device '{device_name}' is not "
                        f"naturally-aligned"
                    )
            # check that registers are contiguous (have no holes)
            expected = [min(offset_string) + (4 * i) for i in range(len(offset_string))]
            if offset_string != expected:
                raise ValueError(
                    f"Multi-register '{register_name}' in device '{device_name}' is not contiguous"
                )
        # check that device registers are non-overlapping.
        # as we have checked already that all registers are the same size
        # and naturally aligned, it suffices to check that all register offsets
        # are unique.
        reg_offsets = [x for reg in registers for x in reg["offsets"]]
        if len(reg_offsets) != len(set(reg_offsets)):
            raise ValueError(f"Device '{device_name}' has overlapping registers")


"""Attribute string for an aligned struct."""
struct_aligned_attribute = "[[gnu::aligned(4)]]"

# attributes for enum definitions
"""Attribute string for 'flag' enums."""
enum_attributes = "[[clang::flag_enum]]"


def indent_lines(lines: list[str]) -> list[str]:
    return [(" " * 4) + line for line in lines]


def fields_ascending_by_lsb(register: dict) -> list[dict]:
    """Sort a register's fields in ascending order of lsb."""
    return sorted(register["fields"], key=lambda field: field["lsb"])


def registers_are_structurally_equal(a: dict, b: dict) -> bool:
    """Returns whether two registers have equivalent declaration structure."""
    try:
        for f, g in zip(fields_ascending_by_lsb(a), fields_ascending_by_lsb(b), strict=True):
            if f["name"] != g["name"] or f["lsb"] != g["lsb"] or f["width"] != g["width"]:
                # differing names, lsb, or field width, therefore not equal
                return False
        return True
    except ValueError:
        # different number of fields in the registers, therefore not equal
        return False


def longest_common_prefix(strings: list[str]) -> str:
    """Find the longest string that is a prefix of all the strings in the list."""
    if not strings:
        return ""
    first = strings[0]
    for i in range(len(first)):
        for string in strings[1:]:
            if i >= len(string) or string[i] != first[i]:
                return first[:i]
    return first


def stripped_longest_common_prefix(strings: list[str]) -> str:
    return longest_common_prefix(strings).rstrip("_").lower()


def register_is_u32_repr(reg: dict) -> bool:
    """
    Predicate that checks whether a register can be represented as a plain uint32_t, instead of its
    own register type.
    """
    fields = reg["fields"]
    if len(fields) == 1 and fields[0]["width"] == 32:
        # register consists of a single 32-bit field
        return True
    if len(fields) == 32:
        for i, field in enumerate(fields_ascending_by_lsb(reg)):
            if field["lsb"] != i or field["width"] != 1:
                return False
        # register consists of 32 1-bit fields
        return True
    return False


def register_is_flag_enum(reg: dict) -> bool:
    """
    Predicate that checks whether a register consists of only contiguous 1-bit fields starting at
    the LSB of the register, so that the register fields can be emitted as a C enum. Does not apply
    for registers with 32 1-bit fields as those are lowered to a single uint32_t, and for 1 1-bit
    field as there is no advantage in having an enum with a single variant over a boolean field.
    """
    fields = reg["fields"]
    if len(fields) == 1 or len(fields) == 32:
        return False
    for i, field in enumerate(fields_ascending_by_lsb(reg)):
        if field["lsb"] != i or field["width"] != 1:
            return False
    return True


def emit_register_flag_enum(device_name: str, reg: dict) -> str:
    """
    Emit register as a flag enum, see 'register_is_flag_enum' predicate.
    """
    reg_name = reg["name"].lower()
    fully_qualified_type_name = "_".join([device_name, reg_name])
    enum_variants = []
    for bit, field in enumerate(fields_ascending_by_lsb(reg)):
        field_name = field["name"].lower()
        fully_qualified_field_name = "_".join([device_name, reg_name, field_name])
        enum_variants.append(f"{fully_qualified_field_name} = (1u << {bit}),")
    return "\n".join(
        [
            f"typedef enum {enum_attributes} {fully_qualified_type_name} : uint32_t {{",
            "\n".join(indent_lines(enum_variants)),
            f"}} {fully_qualified_type_name};",
        ]
    )


def emit_common_device_register_declaration(
    device_name: str, register_set: list[dict]
) -> tuple[str, str]:
    common_name = stripped_longest_common_prefix([x["name"] for x in register_set])
    fully_qualified_type_name = "_".join([device_name, common_name])
    enum_variants = []
    for bit, field in enumerate(fields_ascending_by_lsb(register_set[0])):
        field_name = field["name"].lower()
        fully_qualified_field_name = "_".join([device_name, common_name, field_name])
        enum_variants.append(f"{fully_qualified_field_name} = (1u << {bit}),")

    return fully_qualified_type_name, "\n".join(
        [
            f"typedef enum {enum_attributes} {fully_qualified_type_name} : uint32_t {{",
            "\n".join(indent_lines(enum_variants)),
            f"}} {fully_qualified_type_name};",
        ]
    )


def emit_register_bitfields(device_name: str, reg: dict) -> str:
    """
    Emit register struct. Register fields are represented as bit-fields. Gaps between register
    fields are filled with unnamed padding fields. Fields are emitted as 'uint32_t's to force
    word-sized register access.
    """
    last_msb = 0
    reg_name = reg["name"].lower()
    fully_qualified_type_name = "_".join([device_name, reg_name])
    # iterate over register fields in ascending order of lsb
    field_declarations = []
    for field in fields_ascending_by_lsb(reg):
        field_name = field["name"].lower()
        field_width = field["width"]
        field_lsb, field_msb = field["lsb"], field["msb"]
        padding_bits = (field_lsb - last_msb) - 1
        last_msb = field_msb
        if padding_bits > 0:
            # if there needs to be any padding, emit an unnamed padding field
            field_declarations.append(f"uint32_t : {padding_bits};")
        field_declarations.append(f"uint32_t {field_name} : {field_width};")
    last_field = fields_ascending_by_lsb(reg)[-1]
    if last_field["msb"] < 31:
        padding_bits = 31 - last_field["msb"]
        field_declarations.append(f"uint32_t : {padding_bits};")

    return "\n".join(
        [
            f"typedef struct {struct_aligned_attribute} {{",
            "\n".join(indent_lines(field_declarations)),
            f"}} {fully_qualified_type_name};",
        ]
    )


def get_and_emit_register_types(
    device_name: str, registers: list[dict]
) -> tuple[list[tuple[dict, str]], str]:
    """ """
    # group sets of registers together into equivalence classes based on whether they are
    # structurally equal. see also 'registers_are_structurally_equal'. these equivalence classes are
    # used to possibly emit a single type definition for a set of registers.
    equivalent_register_sets = [
        [x for x in registers if registers_are_structurally_equal(reg, x)] for reg in registers
    ]
    register_equivalence_classes = []
    for reg_set in equivalent_register_sets:
        if reg_set not in register_equivalence_classes:
            register_equivalence_classes.append(reg_set)

    typed_registers: list[tuple[dict, str]] = []
    common_type_declarations: list[str] = []
    type_declarations: list[str] = []
    # iterate over all equivalence classes of registers.
    for group in register_equivalence_classes:
        # for now, de-duplicating definitions is only done for registers that can have a
        # 'flag enum' representation.
        if len(group) > 1 and register_is_flag_enum(group[0]):
            # emit a single 'flag enum' type for the registers in the class.
            reg_type_name, reg_type_decl = emit_common_device_register_declaration(
                device_name, group
            )
            # all the registers in the class use this generated type.
            typed_registers.extend((reg, reg_type_name) for reg in group)
            # append the declaration.
            common_type_declarations.append(reg_type_decl)
            continue
        # either this group contains one register, or contains many registers but was not handled
        # above. in this case generate types for each register individually.
        for reg in group:
            reg_name = reg["name"].lower()
            fully_qualified_type_name = "_".join([device_name, reg_name])
            # get the generated register type declaration and name of that register type.
            reg_type_name = fully_qualified_type_name
            reg_type_decl = None
            if register_is_u32_repr(reg):
                # if the register is representable as a uint32_t, use that type and do not generate
                # a declaration.
                reg_type_name = "uint32_t"
            elif register_is_flag_enum(reg):
                # if the register is representable as a 'flag enum', emit that.
                reg_type_decl = emit_register_flag_enum(device_name, reg)
            else:
                # if there are no special representations, by default emit as a struct
                # with bitfields.
                reg_type_decl = emit_register_bitfields(device_name, reg)
            # append the register with its type name.
            typed_registers.append((reg, reg_type_name))
            # append the declaration, if it exists.
            if reg_type_decl:
                type_declarations.append(reg_type_decl)

    return (typed_registers, "\n\n".join(common_type_declarations + type_declarations))


def emit_device_register_field(device_name: str, reg: dict, type_name: str) -> str:
    """
    Emit the declaration of a register in the device memory layout structure declaration. If the
    register is not software-writable, the register is declared 'const'. If the register has
    multiple contiguous instances, the register is declared as an array of the register type.
    """
    reg_name = reg["name"].lower()
    offsets = reg["offsets"]
    min_offset, max_offset = min(offsets), max(offsets)
    num_regs = len(offsets)
    offset_string = hex(min_offset) if num_regs == 1 else f"{hex(min_offset)}-{hex(max_offset)}"
    return "\n".join(
        indent_lines(
            [
                f"/* {device_name}.{reg_name} ({offset_string}) */",
                f"{'const ' if not reg['sw_writable'] else ''}{type_name} "
                f"{reg_name}{f'[{num_regs}]' if num_regs > 1 else ''};",
            ]
        )
    )


def emit_device_window_field(device_name: str, window: dict) -> str:
    window_name = window["name"].lower()
    num_u32s = window["entries"]
    offset = window["offset"]
    end = offset + window["size"] - 4
    offset_string = f"{hex(offset)}-{hex(end)}"
    return "\n".join(
        indent_lines(
            [
                f"/* {device_name}.{window_name} ({offset_string}) */",
                f"{'const ' if not window['sw_writable'] else ''}uint32_t "
                f"{window_name}[{num_u32s}];",
            ]
        )
    )


def emit_device_register_padding_field(entry_num, end_of_last, start_of_next) -> str:
    """Emit a padding field in the device memory layout structure declaration."""
    string = f"{hex(start_of_next)} - {hex(end_of_last)}"
    return indent_lines([f"const uint8_t __reserved{entry_num}[{string}];"])[0]


def emit_device_struct_declaration(
    device_name: str, typed_registers: list[tuple[dict, str]], windows: list[dict]
) -> str:
    """
    Emit the declaration of the device's memory layout. The fields of this structure are the
    device's registers, with necessary padding fields around them.
    """
    typed_registers_ascending_by_offset = sorted(
        typed_registers, key=lambda reg: min(reg[0]["offsets"])
    )

    # number of padding fields in the struct so far
    padding_field_num = 0
    # top offset of last register field, used to calculate size of padding
    end_of_last_reg = 0
    # iterate over the register in ascending order of offset
    device_struct_reg_declarations = []
    for reg, reg_type_name in typed_registers_ascending_by_offset:
        offsets = reg["offsets"]
        start_of_reg = min(offsets)
        if (start_of_reg - end_of_last_reg) > 0:
            device_struct_reg_declarations.append(
                emit_device_register_padding_field(padding_field_num, end_of_last_reg, start_of_reg)
            )
            padding_field_num += 1
        end_of_last_reg = max(offsets) + 4
        device_struct_reg_declarations.append(
            emit_device_register_field(device_name, reg, reg_type_name)
        )
    for window in windows:
        start_of_reg = window["offset"]
        if (start_of_reg - end_of_last_reg) > 0:
            device_struct_reg_declarations.append(
                emit_device_register_padding_field(padding_field_num, end_of_last_reg, start_of_reg)
            )
            padding_field_num += 1
        end_of_last_reg = start_of_reg + window["size"]
        device_struct_reg_declarations.append(emit_device_window_field(device_name, window))
    return "\n".join(
        [
            f"typedef volatile struct {struct_aligned_attribute} {device_name}_memory_layout {{",
            "\n\n".join(device_struct_reg_declarations),
            f"}} *{device_name}_t;",
        ]
    )


def emit_assertions(
    device_name: str, typed_registers: list[tuple[dict, str]], windows: list[dict]
) -> str:
    """
    Emit static assertions to ensure properties of the generated code.
    These consist of:
        An offset assertion for each register field and buffer window of the device to check that
        the register/window starts at the expected offset within the memory layout of the device.
        A sizeof assertion for each unique register type declaration to check that the register is
        word-sized.
    """

    # sort registers in ascending order of register offset
    registers = [reg for reg, _ in sorted(typed_registers, key=lambda x: min(x[0]["offsets"]))]

    offsetof_assertions = []
    for reg in registers:
        reg_name = reg["name"].lower()
        offsetof_assertions.append(
            f"_Static_assert(__builtin_offsetof(struct {device_name}_memory_layout, {reg_name})"
            f" == {hex(min(reg['offsets']))}ul,\n"
            f'               "incorrect register {reg_name} offset");\n'
        )
    for window in windows:
        window_name = window["name"].lower()
        offsetof_assertions.append(
            f"_Static_assert(__builtin_offsetof(struct {device_name}_memory_layout, {window_name})"
            f" == {hex(window['offset'])}ul,\n"
            f'               "incorrect register window {window_name} offset");\n'
        )

    # de-duplicate types, maintaining their order
    types = []
    for _, ty in typed_registers:
        if ty not in types:
            types.append(ty)

    sizeof_assertions = [
        f"_Static_assert(sizeof({ty}) == sizeof(uint32_t),\n"
        f'               "register type {ty} is not register sized");\n'
        for ty in types
        # clang will warn on a redundant 'sizeof(uint32_t) == sizeof(uint32_t)' assertion
        if ty != "uint32_t"
    ]

    return "".join(offsetof_assertions) + "\n" + "".join(sizeof_assertions)


def gen_device_register_c_headers(args) -> None:
    input_file = Path(args.input_file)
    with input_file.open("r") as f:
        rdl = json.load(f)
    output_dir = Path(args.out_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # only process devices that have a register interface.
    devices = [
        dev
        for dev in rdl["devices"]
        if (dev.get("interfaces") and dev["interfaces"][0].get("regs"))
    ]

    check_register_rdl(devices)

    for device in devices:
        device_name = device["name"].lower()

        registers = device["interfaces"][0]["regs"]
        windows = device["interfaces"][0]["windows"]

        # this first pass processes the list of registers and generates type declarations.
        # the pass returns the given registers paired with name of the type generated to represent
        # them, as well as the string containing all of the register type declarations.
        typed_registers, register_type_declarations = get_and_emit_register_types(
            device_name, registers
        )

        # using the registers and their types, emit the declaration of the structure.
        device_struct_declaration = emit_device_struct_declaration(
            device_name, typed_registers, windows
        )

        # emit assertions for all the registers and generated register types.
        assertions = emit_assertions(device_name, typed_registers, windows)

        output = "\n\n".join(
            [
                register_type_declarations,
                device_struct_declaration,
                assertions,
            ]
        )

        device_header = output_dir / f"{device_name}.h"
        with Path.open(device_header, "w") as f:
            # emit license and auto-generation file header.
            emit_file_header(f, comment_open="// ")
            # emit the required preprocessor statements.
            f.write("\n#pragma once\n\n#include <stdbool.h>\n#include <stdint.h>\n\n")
            # emit the generated C code.
            f.write(output)


def main():
    parser = argparse.ArgumentParser(description="Systemrdl generator utility")
    subparsers = parser.add_subparsers(dest="command", required=True, help="Sub-commands")

    # Subparser for gen_linker_script
    linker_parser = subparsers.add_parser(
        "gen-linker-script", help="Generate a linker file with the memory map."
    )
    linker_parser.add_argument("input_file", type=Path, help="Input JSON file generated by rdl2ot")
    linker_parser.add_argument(
        "out_file",
        type=Path,
        nargs="?",
        default=Path("./build/memory.ld"),
        help="Output filename. (default: %(default)s)",
    )
    linker_parser.set_defaults(func=gen_linker_script)

    # Subparser for gen_memory_map
    map_parser = subparsers.add_parser(
        "gen-memory-map", help="Generate a svg file with the memory map."
    )
    map_parser.add_argument("input_file", type=Path, help="Input JSON file generated by rdl2ot")
    map_parser.add_argument(
        "out_file",
        type=Path,
        nargs="?",
        default=Path("./build/memmap.svg"),
        help="Output filename. (default: %(default)s)",
    )
    map_parser.set_defaults(func=gen_memory_map)

    # Subparser for gen_register_dif
    register_parser = subparsers.add_parser(
        "gen-device-headers", help="Generate device register interface C headers."
    )
    register_parser.add_argument(
        "input_file", type=Path, help="Input JSON file generated from rdl2ot"
    )
    register_parser.add_argument(
        "out_dir",
        type=Path,
        nargs="?",
        default=Path("./sw/device/lib/hal/autogen"),
        help="Output directory for auto-generated register DIF code. (default: %(default)s)",
    )
    register_parser.set_defaults(func=gen_device_register_c_headers)

    # Parse and execute
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
