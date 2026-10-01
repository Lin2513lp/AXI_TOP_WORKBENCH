SHELL := /bin/bash
.DEFAULT_GOAL := all
.PHONY: all m s verdi
all: m s
m:
	$(MAKE) -C AXI_M_TOP all
s:
	$(MAKE) -C AXI_S_TOP all
MODULE ?= AXI_M_TOP
verdi:
	@test "$(MODULE)" = AXI_M_TOP -o "$(MODULE)" = AXI_S_TOP || { echo "MODULE must be AXI_M_TOP or AXI_S_TOP"; exit 1; }
	$(MAKE) -C $(MODULE) verdi
