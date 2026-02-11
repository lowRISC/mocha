// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "runtime/print.h"
#include "hal/uart.h"
#include "runtime/string.h"
#include <stdarg.h>
#include <stddef.h>
#include <stdint.h>
#if defined(__riscv_zcherihybrid)
#include <cheriintrin.h>
#endif /* defined(__riscv_zcherihybrid) */

/* represents an object that can be written to. */
struct sink {
    /* sink write function.
     * writes up to 'len' bytes pointed to by 'str'.
     * returns how many bytes were written. */
    size_t (*write)(uintptr_t data, const char *str, size_t len);

    /* arbitrary sink pointer data. used by the write implementation. */
    uintptr_t data;
};

/* format specifier parser state */
enum format_spec {
    FMT_NONE, /* "%", initial state (invalid) */
    FMT_PERCENT, /* "%%" */
    FMT_CHAR, /* "%c" */
    FMT_STR, /* "%s" */
    FMT_HEX, /* "%x" */
    FMT_LONG, /* "%l" (invalid) */
    FMT_LONG_HEX, /* "%lx" */
    FMT_PTR, /* "%p" */
    FMT_HASH, /* "%#" (invalid) */
    FMT_CAP, /* "%#p" (CHERI) */
};

/* whether the format specifier is valid or not. */
static bool format_spec_is_valid(const enum format_spec spec)
{
    switch (spec) {
    case FMT_NONE:
    case FMT_LONG:
    case FMT_HASH:
        return false;
    case FMT_PERCENT:
    case FMT_CHAR:
    case FMT_STR:
    case FMT_HEX:
    case FMT_LONG_HEX:
    case FMT_PTR:
    case FMT_CAP:
        return true;
    }
}

/* try to consume a character and update the format specifier state machine.
 * if true is returned, the character was consumed and the format specifier
 * state was updated, otherwise the state is unchanged. */
static bool format_spec_next(enum format_spec *cur, const char c)
{
    enum format_spec spec;
    switch (*cur) {
    case FMT_NONE:
        switch (c) {
        case '%':
            spec = FMT_PERCENT;
            break;
        case 'c':
            spec = FMT_CHAR;
            break;
        case 's':
            spec = FMT_STR;
            break;
        case 'x':
            spec = FMT_HEX;
            break;
        case 'l':
            spec = FMT_LONG;
            break;
        case 'p':
            spec = FMT_PTR;
            break;
        case '#':
            spec = FMT_HASH;
            break;
        default:
            return false;
        }
        break;
    case FMT_LONG:
        if (c == 'x') {
            spec = FMT_LONG_HEX;
        } else {
            return false;
        }
        break;
    case FMT_HASH:
        if (c == 'p') {
            spec = FMT_CAP;
        } else {
            return false;
        }
        break;
    case FMT_PERCENT:
    case FMT_CHAR:
    case FMT_STR:
    case FMT_HEX:
    case FMT_LONG_HEX:
    case FMT_PTR:
    case FMT_CAP:
        return false;
    }
    *cur = spec;
    return true;
}

/* hexadecimal alphabet */
static const char HEX[16 + 1] = "0123456789abcdef";

/* consumes characters in 'format' up to the next '%', or until the end of string,
 * updating 'format'. writes out consumed characters to the sink. returns whether
 * the start of a format specifier was reached. */
static bool consume_until_percent(struct sink sink, size_t *written, const char **format)
{
    size_t len = 0;
    while (true) {
        char c = (*format)[len];
        if (c == '\0' || c == '%') {
            if (len > 0) {
                *written += sink.write(sink.data, *format, len);
            }
            *format += len;
            return c != '\0';
        }
        len++;
    }
}

/* parses a format specifier by consuming characters from 'format'.
 * if the format specifier is not valid, writes to the sink a representation of an
 * invalid format specifier. returns whether the parsed format specifier is valid. */
static bool consume_format_spec(struct sink sink, size_t *written, const char **format,
                                enum format_spec *spec)
{
    *spec = FMT_NONE;
    size_t spec_len = 1; /* consume the initial '%' */

    while ((*format)[spec_len] != '\0') {
        if (!format_spec_next(spec, (*format)[spec_len])) {
            break;
        }
        spec_len++;
    }

    bool valid = format_spec_is_valid(*spec);
    if (!valid) {
        *written += sink.write(sink.data, *format, spec_len);
    }
    *format += spec_len;
    return valid;
}

static size_t format_hex(char buf[static 2 * sizeof(uint64_t)], size_t bytes, uint64_t value)
{
    for (size_t i = 2 * bytes; i > 0; i--) {
        buf[i - 1] = HEX[value % 16];
        value >>= 4;
    }
    return 2 * bytes;
}

#if defined(__riscv_zcherihybrid)

static size_t format_string_literal(char *buf, const char *str)
{
    size_t len = strlen(str);
    for (size_t i = 0; i < len; i++) {
        buf[i] = str[i];
    }
    return len;
}

/* format a capability, in a format similar to cheriBSD's "%#p" */
static size_t format_capability(char *buf, const uintptr_t value)
{
    size_t total = 0;
    /* print address part of capability */
    buf[total++] = '0';
    buf[total++] = 'x';
    total += format_hex(&buf[total], sizeof(uint64_t), cheri_address_get(value));
    /* if the high part of the capability is all 0s, this is a null capability with some
     * integer part, so return having printed it as just an integer */
    if (!cheri_high_get(value)) {
        return total;
    }

    buf[total++] = ' ';
    buf[total++] = '[';

    /* capability permissions to check */
    cheri_perms_t perms[7] = {
        CHERI_PERM_READ,
        CHERI_PERM_WRITE,
        CHERI_PERM_EXECUTE,
        CHERI_PERM_READ | CHERI_PERM_CAP,
        CHERI_PERM_WRITE | CHERI_PERM_CAP,
        CHERI_PERM_LOAD_MUTABLE,
        CHERI_PERM_SYSTEM_REGS,
    };
    /* permission characters to print */
    const char perm_chars[7] = {
        'r', 'w', 'x', 'R', 'W', 'M', 'S',
    };
    bool any_perms = false;
    for (size_t i = 0; i < 7; i++) {
        if ((cheri_perms_get(value) & perms[i]) == perms[i]) {
            buf[total++] = perm_chars[i];
            any_perms = true;
        }
    }
    /* if any permissions were printed, append a comma before the base and top */
    if (any_perms) {
        buf[total++] = ',';
    }

    /* print capability base and top addresses */
    buf[total++] = '0';
    buf[total++] = 'x';
    total += format_hex(&buf[total], sizeof(uint64_t), cheri_base_get(value));
    buf[total++] = '-';
    buf[total++] = '0';
    buf[total++] = 'x';
    total +=
        format_hex(&buf[total], sizeof(uint64_t), cheri_base_get(value) + cheri_length_get(value));
    buf[total++] = ']';

    /* print capability attributes: any of "invalid", "sentry", or "sealed" in parentheses */
    if (!cheri_is_valid(value) || cheri_is_sentry(value) || cheri_is_sealed(value)) {
        buf[total++] = ' ';
        buf[total++] = '(';
        bool comma = false;
        if (!cheri_is_valid(value)) {
            total += format_string_literal(&buf[total], "invalid");
            comma = true;
        }
        if (cheri_is_sentry(value)) {
            if (comma) {
                buf[total++] = ',';
            }
            total += format_string_literal(&buf[total], "sentry");
            comma = true;
        }
        if (cheri_is_sealed(value)) {
            if (comma) {
                buf[total++] = ',';
            }
            total += format_string_literal(&buf[total], "sealed");
        }
        buf[total++] = ')';
    }
    return total;
}
#endif /* defined(__riscv_zcherihybrid) */

static void do_format_specifier(struct sink sink, size_t *written, const enum format_spec spec,
                                va_list *arg)
{
    char buf[128];
    const char *str = buf;
    size_t len = 0;

    switch (spec) {
    case FMT_PERCENT:
        /* %%: literal '%' */
        buf[0] = '%';
        len = 1;
        break;
    case FMT_CHAR:
        /* %c: character */
        buf[0] = (char)va_arg(*arg, int);
        len = 1;
        break;
    case FMT_STR:
        /* %s: string */
        str = va_arg(*arg, const char *);
        len = strlen(str);
        break;
    case FMT_HEX:
        /* %x: hexadecimal 32-bit value */
        len = format_hex(buf, sizeof(uint32_t), va_arg(*arg, uint32_t));
        break;
    case FMT_LONG_HEX:
        /* %lx: hexadecimal register-sized value */
        len = format_hex(buf, sizeof(unsigned long), va_arg(*arg, uint64_t));
        break;
    case FMT_PTR:
        /* %p: pointer */
#if defined(__riscv_zcherihybrid)
        len = format_hex(buf, sizeof(unsigned long), cheri_address_get(va_arg(*arg, void *)));
#else /* !defined(__riscv_zcherihybrid) */
        len = format_hex(buf, sizeof(unsigned long), (uintptr_t)va_arg(*arg, void *));
#endif /* defined(__riscv_zcherihybrid) */
        break;
    case FMT_CAP:
        /* %#p: capability (CHERI) */
#if defined(__riscv_zcherihybrid)
        len = format_capability(buf, *va_arg(*arg, uintptr_t *));
#else /* !defined(__riscv_zcherihybrid) */
        len = format_hex(buf, sizeof(unsigned long), (uintptr_t)va_arg(*arg, void *));
#endif /* defined(__riscv_zcherihybrid) */
        break;
    default:
        return;
    }

    *written += sink.write(sink.data, str, len);
}

/* internal printf function. prints formatted text to an arbitrary destination 'sink'. */
static size_t base_printf(struct sink sink, const char *format, ...)
{
    va_list(args);
    va_start(args, format);

    size_t written = 0;
    while (format[0] != '\0') {
        if (!consume_until_percent(sink, &written, &format)) {
            break;
        };
        enum format_spec fmt_spec;
        if (consume_format_spec(sink, &written, &format, &fmt_spec)) {
            do_format_specifier(sink, &written, fmt_spec, args);
        }
    }

    va_end(args);
    return written;
}

struct buffer_data {
    char *const ptr;
    size_t len;
    size_t written;
};

/* buffer sink write function */
static size_t buffer_write_fn(uintptr_t data, const char *str, size_t len)
{
    struct buffer_data *buf = (struct buffer_data *)data;

    if (buf->written + 1 >= buf->len) {
        return 0;
    }

    size_t remaining_capacity = buf->len - buf->written - 1;
    size_t to_write = remaining_capacity < len ? remaining_capacity : len;

    memcpy(&buf->ptr[buf->written], str, to_write);
    buf->written += to_write;
    buf->ptr[buf->written] = '\0';

    return to_write;
}

/* print up to 'len' bytes of formatted text to buffer pointed to by 'ptr'. */
size_t /* NOLINTNEXTLINE(readability-non-const-parameter) */
snprintf(char *const ptr, size_t len, const char *format, ...)
{
    va_list(args);
    va_start(args, format);

    struct buffer_data buf_data = {
        .ptr = ptr,
        .len = len,
        .written = 0,
    };

    struct sink buffer_sink = {
        .write = &buffer_write_fn,
        .data = (uintptr_t)&buf_data,
    };

    size_t written = base_printf(buffer_sink, format, args);
    va_end(args);
    return written;
}

/* UART sink write function */
static size_t uart_write_fn(uintptr_t data, const char *str, size_t len)
{
    uart_t uart = (uart_t)data;
    for (size_t i = 0; i < len; i++) {
        uart_putchar(uart, str[i]);
    }
    return len;
}

/* print formatted text over UART. */
size_t uprintf(uart_t uart, const char *format, ...)
{
    va_list(args);
    va_start(args, format);

    struct sink uart_sink = {
        .write = &uart_write_fn,
        .data = (uintptr_t)uart,
    };

    size_t written = base_printf(uart_sink, format, args);
    va_end(args);
    return written;
}
