# Makefile for cocotb UART tests

# Simulator - using Verilator for fast simulation
SIM ?= verilator

# Top level module
TOPLEVEL = uart

# Source files (use your fixed versions)
VERILOG_SOURCES = clk_gen.sv fifo.sv uart.sv uart_rx.sv uart_tx.sv

# Python test module
MODULE = test_uart

# Verilator specific settings
ifeq ($(SIM),verilator)
    COMPILE_ARGS += -Wno-TIMESCALEMOD -Wno-LITENDIAN -Wno-WIDTH -Wno-REALCVT -Wno-CASEINCOMPLETE
    COMPILE_ARGS += --trace --trace-structs --trace-params --trace-max-array 1024
    EXTRA_ARGS += --trace-fst --trace-max-width 256
    # Enable coverage if desired
    # COMPILE_ARGS += --coverage
endif

# Cocotb parameters
# EXTRA_ARGS += --timescale=1ns/1ps

# Include cocotb's make rules
include $(shell cocotb-config --makefiles)/Makefile.sim

# Convenience targets
.PHONY: clean_all
clean_all: clean
	rm -rf __pycache__ .pytest_cache *.vcd *.fst

# Run specific test
.PHONY: test_%
test_%:
	MODULE=test_uart TESTCASE=$* make

# Run with waveform tracing
.PHONY: waves
waves:
	WAVES=1 MODULE=test_uart make
	
# View waveforms (requires GTKWave)
.PHONY: view
view:
	@if [ -f "dump.fst" ]; then \
		gtkwave dump.fst; \
	elif [ -f "uart.fst" ]; then \
		gtkwave uart.fst; \
	elif [ -f "*.vcd" ]; then \
		gtkwave *.vcd; \
	else \
		echo "No waveform file found. Run 'make waves' first."; \
	fi

# Performance test (disable waveforms for speed)
.PHONY: perf
perf:
	MODULE=test_uart WAVES=0 make