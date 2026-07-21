// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include <stdint.h>

// SW-to-DV logging: writes a log_fields_t entry address + arguments to
// SW_DV_LOG_ADDR; sw_logger_if reconstructs the formatted string in simulation.

// Log severity levels, decoded by sw_logger_if. Fixed to uint32_t so the
// log_fields_t layout stays stable for extract_sw_logs.py.
enum dv_log_severity : uint32_t {
    dv_log_severity_info = 0,
    dv_log_severity_warning = 1,
    dv_log_severity_error = 2,
    dv_log_severity_fatal = 3,
};

// const char * for string fields: required for a valid C99 static initialiser
// (pointer-to-integer casts are not constant expressions).  extract_sw_logs.py
// detects the rv64 ELF class and uses '<I4xQIIQ' (32 B) instead of '<IIIII'.
typedef struct {
    enum dv_log_severity severity;
    const char *file;
    uint32_t line;
    uint32_t nargs;
    const char *format;
} log_fields_t;

// Writes the log entry address followed by each argument to SW_DV_LOG_ADDR.
void dv_log_write(const log_fields_t *log, ...);

// Count variadic arguments (0–8). DV_LOG_NARGS_SEQ_ is used directly by
// DV_LOG_ rather than via a wrapper; see comment on DV_LOG_ for why.
#define DV_LOG_NARGS_SEQ_(x1, x2, x3, x4, x5, x6, x7, x8, x9, N, ...) N

// Build a unique identifier per call site by pasting the line number onto the
// prefix, e.g. dv_log_entry_42, so each DV_LOG_ call defines its own static
// log_fields_t entry without name clashes.
#define DV_LOG_CONCAT_(a, b) a##b
#define DV_LOG_UNIQUE_(pfx)  DV_LOG_CONCAT_(pfx, __LINE__)

// Internal macro shared by all severity levels.
// DV_LOG_NARGS_SEQ_ is used inline (not via DV_LOG_NARGS wrapper) so that
// ##__VA_ARGS__ operates directly on DV_LOG_'s own __VA_ARGS__.  Passing
// __VA_ARGS__ through an extra macro call causes Clang to treat the empty
// pack as one empty argument, returning N=1 instead of N=0 for 0-arg calls.
#define DV_LOG_(sev, fmt, ...) \
    do { \
        static const log_fields_t DV_LOG_UNIQUE_(dv_log_entry_) \
            __attribute__((section(".logs.fields"), used)) = { \
                .severity = (sev), \
                .file = __FILE__, \
                .line = (uint32_t)__LINE__, \
                .nargs = DV_LOG_NARGS_SEQ_(x, ##__VA_ARGS__, 8, 7, 6, 5, 4, 3, 2, 1, 0), \
                .format = (fmt), \
            }; \
        dv_log_write(&DV_LOG_UNIQUE_(dv_log_entry_), ##__VA_ARGS__); \
    } while (0)

#define DV_LOG_INFO(fmt, ...)    DV_LOG_(dv_log_severity_info, fmt, ##__VA_ARGS__)
#define DV_LOG_WARNING(fmt, ...) DV_LOG_(dv_log_severity_warning, fmt, ##__VA_ARGS__)
#define DV_LOG_ERROR(fmt, ...)   DV_LOG_(dv_log_severity_error, fmt, ##__VA_ARGS__)
#define DV_LOG_FATAL(fmt, ...)   DV_LOG_(dv_log_severity_fatal, fmt, ##__VA_ARGS__)
