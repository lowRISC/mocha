#!/usr/bin/env -S bash -eux
# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

npm install
wget --no-clobber https://raw.githubusercontent.com/marnovandermaas/tool-schema/refs/heads/main/tool_schema.json
node_modules/.bin/ajv validate --spec=draft2020 -s tool_schema.json -d tool_data.json
