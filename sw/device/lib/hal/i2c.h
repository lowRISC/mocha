// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include <stdbool.h>
#include <stdint.h>

#define I2C_INTR_STATE_REG              (0x00)
#define I2C_INTR_STATE_FMT_THRESHOLD    (0)
#define I2C_INTR_STATE_RX_THRESHOLD     (1)
#define I2C_INTR_STATE_ACQ_THRESHOLD    (2)
#define I2C_INTR_STATE_RX_OVERFLOW      (3)
#define I2C_INTR_STATE_CONTROLLER_HALT  (4)
#define I2C_INTR_STATE_SCL_INTERFERENCE (5)
#define I2C_INTR_STATE_SDA_INTERFERENCE (6)
#define I2C_INTR_STATE_STRETCH_TIMEOUT  (7)
#define I2C_INTR_STATE_SDA_UNSTABLE     (8)
#define I2C_INTR_STATE_CMD_COMPLETE     (9)
#define I2C_INTR_STATE_TX_STRETCH       (10)
#define I2C_INTR_STATE_TX_THRESHOLD     (11)
#define I2C_INTR_STATE_ACQ_STRETCH      (12)
#define I2C_INTR_STATE_UNEXP_STOP       (13)
#define I2C_INTR_STATE_HOST_TIMEOUT     (14)

#define I2C_CTRL_REG                         (0x10)
#define I2C_CTRL_ENABLEHOST                  (0)
#define I2C_CTRL_ENABLETARGET                (1)
#define I2C_CTRL_LLPBK                       (2)
#define I2C_CTRL_NACK_ADDR_AFTER_TIMEOUT     (3)
#define I2C_CTRL_ACK_CTRL_EN                 (4)
#define I2C_CTRL_MULTI_CONTROLLER_MONITOR_EN (5)
#define I2C_CTRL_TX_STRETCH_CTRL_EN          (6)

#define I2C_STATUS_REG              (0x14)
#define I2C_STATUS_FMTFULL          (0)
#define I2C_STATUS_RXFULL           (1)
#define I2C_STATUS_FMTEMPTY         (2)
#define I2C_STATUS_HOSTIDLE         (3)
#define I2C_STATUS_TARGETIDLE       (4)
#define I2C_STATUS_RXEMPTY          (5)
#define I2C_STATUS_TXFULL           (6)
#define I2C_STATUS_ACQFULL          (7)
#define I2C_STATUS_TXEMPTY          (8)
#define I2C_STATUS_ACQEMPTY         (9)
#define I2C_STATUS_ACK_CTRL_STRETCH (10)

#define I2C_RDATA_REG (0x18)

#define I2C_FDATA_REG   (0x1C)
#define I2C_FDATA_FBYTE (0)
#define I2C_FDATA_START (8)
#define I2C_FDATA_STOP  (9)
#define I2C_FDATA_READB (10)
#define I2C_FDATA_RCONT (11)
#define I2C_FDATA_NAKOK (12)

#define I2C_FIFO_CTRL_REG    (0x20)
#define I2C_FIFO_CTRL_RXRST  (0)
#define I2C_FIFO_CTRL_FMTRST (1)
#define I2C_FIFO_CTRL_ACQRST (7)
#define I2C_FIFO_CTRL_TXRST  (8)

#define I2C_TIMING0_REG   (0x3C)
#define I2C_TIMING0_THIGH (0)
#define I2C_TIMING0_TLOW  (16)

#define I2C_TIMING1_REG (0x40)
#define I2C_TIMING1_T_R (0)
#define I2C_TIMING1_T_F (16)

#define I2C_TIMING2_REG     (0x44)
#define I2C_TIMING2_TSU_STA (0)
#define I2C_TIMING2_THD_STA (16)

#define I2C_TIMING3_REG     (0x48)
#define I2C_TIMING3_TSU_DAT (0)
#define I2C_TIMING3_THD_DAT (16)

#define I2C_TIMING4_REG     (0x4C)
#define I2C_TIMING4_TSU_STO (0)
#define I2C_TIMING4_T_BUF   (16)

// Nominal SDA/SCL signal rise and fall time in nanoseconds
// Genesys2 with AS6212 I^2C sensor measured by Saleae analyser: rise ~450ns, fall ~120ns
#define I2C_RISE_NS (450)
#define I2C_FALL_NS (120)

typedef void *i2c_t;

void i2c_init(i2c_t i2c);

bool i2c_write_byte(i2c_t i2c, uint8_t addr, uint8_t data);
uint8_t i2c_read_byte(i2c_t i2c, uint8_t addr);
