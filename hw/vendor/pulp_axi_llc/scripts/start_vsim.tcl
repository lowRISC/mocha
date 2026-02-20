# Copyright 2022 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

# Author: Thomas Benz <tbenz@iis.ee.ethz.ch>

vsim -t 1ps -voptargs=+acc tb_axi_llc -logfile logs/axi_llc.vsim.log -wlf logs/axi_llc.wlf

set StdArithNoWarnings 1
set NumericStdNoWarnings 1
log -r /*
