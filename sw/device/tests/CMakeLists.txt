# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set(LIBS startup hal test_framework)

mocha_add_test(NAME test_framework_test SOURCES test_framework/smoketest.c LIBRARIES ${LIBS})
mocha_add_test(NAME test_framework_exception_test SOURCES test_framework/exception.c LIBRARIES ${LIBS})
mocha_add_test(NAME plic_smoketest SOURCES plic/smoketest.c LIBRARIES ${LIBS})
mocha_add_test(NAME timer_smoketest SOURCES timer/smoketest.c LIBRARIES ${LIBS})
mocha_add_test(NAME uart_smoketest SOURCES uart/smoketest.c LIBRARIES ${LIBS})
