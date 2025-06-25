/* SPDX-License-Identifier: GPL-2.0 */
/* Copyright (C) 2024 Intel Corporation */

#ifndef MAX929X_H
#define MAX929X_H

#define MAX929X_NAME "max929x"
#define MAX9295_I2C_ADDRESS 0x40

/* set this flag if this module needs serializer initialization */
#define MAX9295_FL_INIT_SER	BIT(0)
/* set this flag if this module has extra powerup sequence */
#define MAX9295_FL_POWERUP	BIT(1)
/* set this flag if this module needs reset signal */
#define MAX9295_FL_RESET	BIT(2)
/* set this flag if it need to init serial clk only */
#define MAX9295_FL_INIT_SER_CLK	BIT(4)

#endif
