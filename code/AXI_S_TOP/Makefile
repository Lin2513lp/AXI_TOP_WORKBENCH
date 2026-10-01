SHELL := /bin/bash
.DEFAULT_GOAL := all
VCS ?= vcs
VERDI ?= verdi
TOP := tb_AXI_S_TOP
PASS_MARKER := AXI_S_TOP PASS
PROJECT_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
# VCS needs symbolic links: build on guest-local storage, not VMware hgfs.
RUN_ROOT ?= $(HOME)/axi_top_runs/AXI_S_TOP
BUILD_DIR := $(RUN_ROOT)/build
LOG_DIR := $(RUN_ROOT)/logs
WAVE_DIR := $(RUN_ROOT)/waves
SIMV := $(BUILD_DIR)/simv
FSDB_FILE := $(WAVE_DIR)/$(TOP).fsdb
COMPILE_LOG := $(LOG_DIR)/compile.log
RUN_LOG := $(LOG_DIR)/simulate.log
RESULT_DIR := $(PROJECT_ROOT)/results
SOURCES := $(PROJECT_ROOT)/rtl/fifo_out.sv $(PROJECT_ROOT)/rtl/fifo2axi.sv $(PROJECT_ROOT)/rtl/AXI_S_TOP.sv $(PROJECT_ROOT)/tb/tb_AXI_S_TOP.sv

SCL_HOME ?= /home/yian/Synopsys/scl/2024.06
LICENSE_SERVER ?= 27000@localhost.localdomain
LICENSE_FILE ?= $(SCL_HOME)/admin/license/synopsys.lic
LMUTIL ?= $(SCL_HOME)/linux64/bin/lmutil
LMGRD ?= $(SCL_HOME)/linux64/bin/lmgrd
# Override stale shell values; select another server with make LICENSE_SERVER=...
SNPSLMD_LICENSE_FILE = $(LICENSE_SERVER)
LM_LICENSE_FILE = $(LICENSE_SERVER)
export SNPSLMD_LICENSE_FILE LM_LICENSE_FILE
VERDI_BIN := $(shell command -v $(VERDI) 2>/dev/null)
VERDI_REAL := $(shell readlink -f "$(VERDI_BIN)" 2>/dev/null)
VERDI_AUTO_ROOT := $(patsubst %/,%,$(dir $(patsubst %/,%,$(dir $(VERDI_REAL)))))
VERDI_ROOT := $(or $(strip $(VERDI_HOME)),$(strip $(NOVAS_HOME)),$(strip $(VERDI_AUTO_ROOT)))
FSDB_TAB := $(VERDI_ROOT)/share/PLI/VCS/LINUX64/novas.tab
FSDB_LIB := $(VERDI_ROOT)/share/PLI/VCS/LINUX64/pli.a
VCS_FLAGS ?= -full64 -sverilog -timescale=1ns/1ps -kdb -debug_access+all
SIM_ARGS ?=

.PHONY: all compile run verdi wave env check dirs help license
all: run

dirs:
	@mkdir -p "$(BUILD_DIR)" "$(LOG_DIR)" "$(WAVE_DIR)" "$(RESULT_DIR)"

check:
	@command -v $(VCS) >/dev/null || { echo "ERROR: vcs is not on PATH"; exit 1; }
	@test -n "$(VERDI_ROOT)" || { echo "ERROR: set VERDI_HOME or put verdi on PATH"; exit 1; }
	@test -f "$(FSDB_TAB)" && test -f "$(FSDB_LIB)" || { echo "ERROR: missing FSDB PLI under $(VERDI_ROOT)"; exit 1; }
	@for src in $(SOURCES); do test -f "$$src" || { echo "ERROR: missing $$src"; exit 1; }; done

license: dirs
	@set -o pipefail; bash "$(PROJECT_ROOT)/scripts/check_license.sh" \
	  "$(SNPSLMD_LICENSE_FILE)" "$(LICENSE_FILE)" "$(LMUTIL)" "$(LMGRD)" \
	  "$(LOG_DIR)" "$(HOME)/axi_top_runs/.license.lock" 2>&1 | tee "$(RESULT_DIR)/license.log"

compile: check license
	@set -o pipefail; cd "$(BUILD_DIR)" && \
	  $(VCS) $(VCS_FLAGS) +define+FSDB_TRACE \
	  -P "$(FSDB_TAB)" "$(FSDB_LIB)" $(SOURCES) -top $(TOP) \
	  -Mdir="$(BUILD_DIR)/csrc" -o "$(SIMV)" 2>&1 | tee "$(COMPILE_LOG)"; \
	  status=$$?; cp "$(COMPILE_LOG)" "$(RESULT_DIR)/compile.log"; exit $$status

run: compile
	@set -o pipefail; cd "$(RUN_ROOT)" && \
	  "$(SIMV)" +FSDB_FILE="$(FSDB_FILE)" $(SIM_ARGS) 2>&1 | tee "$(RUN_LOG)"; \
	  status=$$?; cp "$(RUN_LOG)" "$(RESULT_DIR)/simulate.log"; \
	  if [ $$status -ne 0 ]; then exit $$status; fi; \
	  grep -Fq "$(PASS_MARKER)" "$(RUN_LOG)" || { echo "ERROR: PASS marker missing"; exit 1; }; \
	  if grep -Eq 'Fatal:|Error:|Error-\[|UVM_FATAL|UVM_ERROR' "$(RUN_LOG)"; then echo "ERROR: simulation failed"; exit 1; fi; \
	  test -s "$(FSDB_FILE)" || { echo "ERROR: FSDB missing or empty"; exit 1; }; \
	  cp "$(FSDB_FILE)" "$(RESULT_DIR)/$(TOP).fsdb"; \
	  echo "[PASS] $(TOP)"; echo "[FSDB] $(FSDB_FILE)"; echo "[SHARED RESULTS] $(RESULT_DIR)"

# Run in the VM desktop terminal so DISPLAY/Xauthority come from that session.
verdi wave: license
	@command -v $(VERDI) >/dev/null || { echo "ERROR: verdi is not on PATH"; exit 1; }
	@test -n "$$DISPLAY" || { echo "ERROR: run make verdi in the VM graphical desktop terminal"; exit 1; }
	@test -s "$(FSDB_FILE)" || { echo "ERROR: run make all first"; exit 1; }
	@test -d "$(SIMV).daidir" || { echo "ERROR: VCS debug database missing; run make all"; exit 1; }
	@cd "$(RUN_ROOT)" && $(VERDI) -full64 -ssf "$(FSDB_FILE)" -dbdir "$(SIMV).daidir" -nologo

env:
	@echo "VCS=$$(command -v $(VCS))"
	@echo "VERDI=$$(command -v $(VERDI))"
	@echo "VERDI_ROOT=$(VERDI_ROOT)"
	@echo "PROJECT_ROOT=$(PROJECT_ROOT)"
	@echo "RUN_ROOT=$(RUN_ROOT)"
	@echo "DISPLAY=$$DISPLAY"
	@echo "SNPSLMD_LICENSE_FILE=$(SNPSLMD_LICENSE_FILE)"
	@echo "LICENSE_FILE=$(LICENSE_FILE)"

help:
	@echo "make all   : compile, run basic dataflow TB, generate FSDB"
	@echo "make verdi : open FSDB and VCS source debug database"
	@echo "make env   : show paths"
	@echo "make license : check/recover the local Synopsys license daemon"
	@echo "Results are copied to $(RESULT_DIR); builds stay on guest-local storage."
