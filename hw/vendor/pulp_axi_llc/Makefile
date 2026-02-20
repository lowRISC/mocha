# Copyright 2022 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

# Author: Thomas Benz <tbenz@iis.ee.ethz.ch>

BENDER ?= bender
PYTHON ?= python3

REGGEN_PATH  = $(shell $(BENDER) path register_interface)/vendor/lowrisc_opentitan/util/regtool.py
REGGEN	     = $(PYTHON) $(REGGEN_PATH)

.PHONY: all clean

all: help

clean: sim_clean vcs_clean morty_clean misc_clean

# Ensure half-built targets are purged
.DELETE_ON_ERROR:


# --------------
# help
# --------------

help:
	@echo ""
	@echo "LLC Makefile"
	@echo "-------------"
	@echo ""
	@echo "bin/axi_llc.vcs:                   creates the VCS executable"
	@echo "pickle:                            uses morty to generate a pickled version of the hardware"
	@echo "doc:                               generates the documentation in doc/morty"
	@echo "graph:                             generates the module hierarchy graph in doc/morty-graph"
	@echo "regs:                              generates the RegBus compatible register file"
	@echo ""
	@echo "clean:                             cleans generated files"
	@echo "nuke:                              cleans all generated file, also almost all files checked in"
	@echo ""


# --------------
# Registers
# --------------

regs:
	$(REGGEN) -r --outdir src/ data/axi_llc_regs.hjson
	$(REGGEN) --cdefines --outfile sw/include/axi_llc_regs.h data/axi_llc_regs.hjson

# --------------
# QuestaSim
# --------------

.PHONY: sim_clean

VLOG_ARGS += -suppress vlog-2583 -suppress vlog-13314 -suppress vlog-13233 -timescale \"1 ns / 1 ps\"

define generate_vsim
	echo 'set ROOT [file normalize [file dirname [info script]]/$3]' > $1
	$(BENDER) script vsim --vlog-arg="$(VLOG_ARGS)" $2 | grep -v "set ROOT" >> $1
	echo >> $1
endef

scripts/compile_vsim.tcl: Bender.yml
	$(call generate_vsim, $@, -t rtl -t test,..)

sim_clean:
	rm -rf scripts/compile_vsim.tcl
	rm -rf work
	rm -f  transcript
	rm -f  wlf*
	rm -f  *.wlf
	rm -f  *.vstf
	rm -f  modelsim.ini
	rm -f  logs/*.wlf
	rm -f  logs/vsim.log


# --------------
# VCS
# --------------

.PHONY: vcs_compile vcs_clean

VLOGAN_ARGS := -assert svaext
VLOGAN_ARGS += -assert disable_cover
VLOGAN_ARGS += -full64
VLOGAN_ARGS += -sysc=q
VLOGAN_ARGS += -nc
VLOGAN_ARGS += -q
VLOGAN_ARGS += -timescale=1ns/1ns

VCS_ARGS    := -full64
VCS_ARGS    += -Mlib=work-vcs
VCS_ARGS    += -Mdir=work-vcs
VCS_ARGS    += -debug_access+r
VCS_ARGS    += -j 8
VCS_ARGS    += -CFLAGS "-Os"
#VCS_ARGS    += -xprop,mode=pass

VCS_PARAMS  ?=
VCS_TB      ?= tb_axi_llc

VLOGAN_BIN  ?= vlogan
VCS_BIN     ?= vcs

VLOGAN_REL_PATHS ?= | grep -v "ROOT=" | sed '3 i ROOT="."'

scripts/compile_vcs.sh: Bender.yml Bender.lock
	$(BENDER) script vcs -t test -t rtl -t simulation --vlog-arg "\$(VLOGAN_ARGS)" --vlogan-bin "$(VLOGAN_BIN)" $(VLOGAN_REL_PATHS) > $@
	chmod +x $@

vcs_compile: scripts/compile_vcs.sh
	scripts/compile_vcs.sh

bin/%.vcs: scripts/compile_vcs.sh vcs_compile
	mkdir -p bin
	$(VCS_BIN) $(VCS_ARGS) $(VCS_PARAMS) $(VCS_TB) -o $@

vcs_clean:
	rm -rf AN.DB
	rm -f  scripts/compile_vcs.sh
	rm -rf bin
	rm -rf work-vcs
	rm -f  ucli.key
	rm -f  vc_hdrs.h
	rm -f  logs/*.vcs.log


# ---------------
# Morty
# ---------------

.PHONY: pickle pickle_clean doc doc_clean graph graph_clean morty_clean

MORTY               ?= morty
MORTY_TOP           ?= axi_llc_reg_wrap
MORTY_TOP_TB        ?= tb_axi_llc
PATH_ESCAPED         = $(shell pwd | sed 's_/_\\/_g')
RELATIVE_PATH_REGEX  = 's/$(PATH_ESCAPED)/./'

pickle: pickle/llc_pickle.sv pickle/llc_pickle_stripped.sv

doc: doc/morty/index.html

graph: doc/morty/llc.png

sources.txt: Bender.yml Bender.lock
	$(BENDER) script flist -t rtl -t synthesis -t pulp -t cva6 | sed -e $(RELATIVE_PATH_REGEX) > $@

sources_tb.txt: Bender.yml Bender.lock
	$(BENDER) script flist -t rtl -t synthesis -t pulp -t simulation -t test -t cva6 | sed -e $(RELATIVE_PATH_REGEX) > $@

sources_llc.txt: Bender.yml Bender.lock
	$(BENDER) script flist -n -t rtl -t synthesis -t pulp -t cva6 | sed -e $(RELATIVE_PATH_REGEX) > $@

pickle/llc_pickle.sv: sources.txt
	mkdir -p pickle
	$(MORTY) --top $(MORTY_TOP) -s _pickle $$(cat sources.txt | sed -e "s/+incdir+/-I /") -o $@

pickle/llc_pickle_stripped.sv: sources.txt
	mkdir -p pickle
	$(MORTY) --top $(MORTY_TOP) --strip-comments -s _pickle_stripped $$(cat sources.txt | sed -e "s/+incdir+/-I /") -o $@

doc/morty/index.html: sources_llc.txt
	mkdir -p doc/morty
	$(MORTY) -i --top $(MORTY_TOP_TB) --doc doc/morty $$(cat sources_llc.txt | sed -e "s/+incdir+/-I /") -o /dev/null

doc/morty/llc.dot: sources_tb.txt
	mkdir -p doc/morty
	$(MORTY) -i --top $(MORTY_TOP_TB) $$(cat sources_tb.txt | sed -e "s/+incdir+/-I /") --graph_file $@ -o /dev/null

doc/morty/llc.png: doc/morty/llc.dot
	dot $^ -Tpng -Granksep=4 -v -Ln25 -o $@

morty_clean: pickle_clean doc_clean graph_clean
	rm -f sources*.txt

pickle_clean:
	rm -rf pickle

doc_clean:
	rm -rf doc/morty

graph_clean:
	rm -f  doc/morty/*.dot
	rm -f  doc/morty/*.png


## --------------
## CI
## --------------

.PHONY: bender-rm

bender:
ifeq (,$(wildcard ./bender))
	curl --proto '=https' --tlsv1.2 -sSf https://pulp-platform.github.io/bender/init \
		| bash -s -- 0.26.1
	touch bender
endif

bender-rm:
	rm -f bender


.PHONY: morty-rm

morty:
ifeq (,$(wildcard ./morty))
	mkdir -p morty-dl
	cd morty-dl; wget https://github.com/pulp-platform/morty/releases/download/v0.8.0/morty-centos.7.9.2009-x86_64.tar.gz
	cd morty-dl; tar -xvf morty-centos.7.9.2009-x86_64.tar.gz; rm -f morty-centos.7.9.2009-x86_64.tar.gz
	mv morty-dl/morty .; rm -rf morty-dl
endif

morty-rm:
	rm -f morty


# --------------
# Misc Clean
# --------------

.PHONY: misc_clean nuke

misc_clean:
	rm -rf scripts/__pycache__
	rm -f  contributions.txt
	rm -f  open_todos.txt
	rm -f  gmon.out

nuke: clean morty-rm bender-rm
	rm -rf .bender
