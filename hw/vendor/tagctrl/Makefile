# Copyright 2023 Bruno Sá and ZeroDay Labs.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

# Author: Bruno Sá <bruno.vilaca.sa@gmailcom>
# TODO:
# 1. Use morty to generate the documentation
# 2. Fetch morty and bender tools automatically
MODULE=tag_ctrl

# root path
ROOT_PATH    := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
TB_PATH    := $(ROOT_PATH)/test
# bender version
bender_tool    ?= bender
# verilator version
verilator      ?= verilator
# verible tool
verible        ?= verible-verilog-format
# source files (conditionally include coverage)
COVERAGE ?= 0
ifeq ($(COVERAGE), 1)
src := $(shell $(bender_tool) script verilator -t synthesis -t synth_test -t tb -t coverage)
VERILATOR_COV_FLAG := --coverage-user
else
src := $(shell $(bender_tool) script verilator -t synthesis -t synth_test -t tb)
VERILATOR_COV_FLAG :=
endif
src_cpp      := $(wildcard $(ROOT_PATH)/test/src/*.cpp)
# verilator lib
ver-library    ?= work-ver
verilator_threads := 1
# additional definess
VM_TRACE ?= 1
# Setup Verilator build directory
VER_BUILD_DIR ?= $(TB_PATH)/$(ver-library)/
# Setup Verilator logs directory
VER_LOGS_DIR ?= $(TB_PATH)/logs/
# Verilator simulator flags
VCD_DUMP ?= "$(VER_BUILD_DIR)dump.vcd"

#Gtest Setup
GTEST_GIT := https://github.com/google/googletest.git
GTEST_BRANCH := v1.10.x
GTEST_DIR := $(VER_BUILD_DIR)gtest/
GTEST_BUILD := $(GTEST_DIR)build/
GTEST_DEFINES := -DBUILD_GMOCK=OFF

#Verilator Flags
CFLAGS := -I$(RISCV)/include                            \
          -std=c++17                                    \
	  -I$(GTEST_BUILD)/googletest/include/          \
          -I$(ROOT_PATH)test/src/inc/                   \
	  -O3
	  #-I$(VERILATOR_ROOT)                           \

ifeq ($(COVERAGE), 1)
CFLAGS += -DCOVERAGE=1
endif

BUILD_MACROS := -DVL_DEBUG
ifdef VM_TRACE
BUILD_MACROS += -DVM_TRACE
# Verilator simulator flags
VCD_DUMP ?= "$(VER_BUILD_DIR)dump.vcd"
endif

LDFLAGS := $(LDFLAGS) -L$(GTEST_BUILD)/lib -L$(RISCV)/lib          \
           -Wl,-rpath,$(RISCV)/lib 						\
		   -lpthread									\
		   -lgtest
		   #-lfesvr                                      \

ifndef RISCV
$(error RISCV not set - please point your RISCV variable to your RISCV installation)
endif

# verilator-specific
verilate_command := $(verilator)                                          \
		    $(VERILATOR_COV_FLAG)                                 \
                    $(src)                                                \
                    --timing \
                    --unroll-count 256                                    \
                    -Wno-PINMISSING                                       \
                    -Wno-ENUMVALUE                                        \
                    -Wno-ZEROREPL                                         \
                    -Wno-IMPLICIT                                         \
                    -Wno-fatal                                            \
                    -Wno-PINCONNECTEMPTY                                  \
                    -Wno-ASSIGNDLY                                        \
                    -Wno-DECLFILENAME                                     \
                    -Wno-UNUSED                                           \
                    -Wno-UNOPTFLAT                                        \
                    -Wno-BLKANDNBLK                                       \
                    -Wno-style                                            \
                    $(if $(VM_TRACE),--trace --trace-structs,)            \
                    -LDFLAGS "$(LDFLAGS)"                                 \
                    -CFLAGS "$(CFLAGS) $(BUILD_MACROS)"                   \
                    -Wall --cc ${TB_PATH}/hdl/$(MODULE)_testharness.sv    \
                    --top-module $(MODULE)_testharness                    \
                    --Mdir $(VER_BUILD_DIR) -O3                           \
                    --exe ${TB_PATH}/src/$(MODULE)_tb.cpp

# verilator-specific
verilate_lint_command := $(verilator)                                     \
                    $(src)                                                \
					--lint-only                                           \
                    --unroll-count 256                                    \
                    -Werror-PINMISSING                                    \
                    -Werror-IMPLICIT                                      \
                    -Wno-fatal                                            \
                    -Wno-PINCONNECTEMPTY                                  \
                    -Wno-ASSIGNDLY                                        \
                    -Wno-DECLFILENAME                                     \
                    -Wno-UNUSED                                           \
                    -Wno-UNOPTFLAT                                        \
                    -Wno-BLKANDNBLK                                       \
                    -Wno-style                                            \
                    --trace --trace-structs                               \
                    -LDFLAGS "$(LDFLAGS)"                                 \
                    -CFLAGS "$(CFLAGS) $(BUILD_MACROS)"                   \
                    -Wall --cc ${TB_PATH}/hdl/$(MODULE)_testharness.sv  \
                    --top-module $(MODULE)_testharness                    \
                    --Mdir $(VER_BUILD_DIR) -O3                           \
                    --exe ${TB_PATH}/src/$(MODULE)_tb.cpp

# verible formatter
verible_src := $(addprefix $(ROOT_PATH), $(shell git ls-tree -r HEAD --name-only | grep '\.sv$$'))
verible_format_command := $(verible)       \
                           --inplace       \
					       $(verible_src)

.PHONY:waves
waves: $(VCD_DUMP)
	@echo
	@echo "<----Open $(VCD_DUMP) in GTKWave---->"
	gtkwave $(VCD_DUMP)
	@echo "<----Close GTKWave---->"

$(VCD_DUMP): verilate

.PHONY:verilate
verilate:
	@echo $(VER_LOGS_DIR)
	@echo "<----Building Verilator Model for $(Module)---->"
	$(verilate_command)
	cd $(VER_BUILD_DIR) && $(MAKE) -j${NUM_JOBS} -f V$(MODULE)_testharness.mk
	@mkdir -p $(VER_LOGS_DIR)

.PHONY:runtests
runtests: $(VER_BUILD_DIR)V$(MODULE)_testharness.mk
	@echo
	@echo "<----Running Tests---->"
	@$(VER_BUILD_DIR)V$(MODULE)_testharness -v $(VER_LOGS_DIR)
	@echo "<----Finish running Tests---->"

.PHONY:gen-cov-rpt
gen-cov-rpt: coverage.dat
	verilator_coverage --filter-type "covergroup" --report summary,hier coverage.dat > coverage.rpt

.PHONY:lint
verilator-lint:
	$(verilate_lint_command)

.PHONY:format
verible-format:
	@echo "<----Formatting source code---->"
	$(verible_format_command)
	@echo "<----Finish formatting source code---->"


.PHONY:gtest
gtest:
	@echo
	@echo "<----Building GTest Framework---->"
	@mkdir -p $(GTEST_BUILD) && cd $(GTEST_BUILD) && cmake $(GTEST_DIR) $(GTEST_DEFINES) && make
	@echo "<----Finish building GTest Framework---->"

$(VER_BUILD_DIR):
	@echo "<----Generate build directory---->"
	@mkdir -p $(VER_BUILD_DIR)
	@echo "<----Finish generating build directory---->"


.PHONY: clean
clean:
	rm -rf .stamp.*;
	rm -rf $(VER_BUILD_DIR)
	rm -rf $(VER_LOGS_DIR)
	rm -f tmp/*.ucdb tmp/*.log *.wlf *vstf wlft* *.ucdb
	rm -rf *.vcd
	rm -rf .bender
	rm -rf coverage.dat coverage.rpt
