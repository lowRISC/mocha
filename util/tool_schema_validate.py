#!/usr/bin/env python
# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import jsonschema

try:
    import json
    import pathlib
    import urllib.error
    import urllib.request

    url_string = ('https://raw.githubusercontent.com/'
                  'marnovandermaas/tool-schema/refs/'
                  'heads/main/tool_schema.json')

    with urllib.request.urlopen(url_string) as url:
        schema = json.loads(url.read())

    with pathlib.Path('tool_data.json').open() as valid_data_file:
        tool_data = json.load(valid_data_file)
except FileNotFoundError as err:
    print('Error: The tool data file was not found.')
    raise SystemExit(1) from err
except json.JSONDecodeError as err:
    print('Error: Failed to decode JSON from the file.')
    raise SystemExit(2) from err
except urllib.error.URLError as err:
    print('Failed to fetch tool schema.')
    raise SystemExit(3) from err

try:
    jsonschema.validate(instance=tool_data, schema=schema)
except jsonschema.ValidationError as err:
    print('Tool data is invalid according to the schema.')
    raise SystemExit(10) from err

# If we get here the tool data has successfully been validated.
raise SystemExit(0)
