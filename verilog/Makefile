# ==============================================================================
# Makefile para o Projeto RISC-V Verilog & FPGA SoC
# ==============================================================================

IVERILOG = iverilog
VVP      = vvp
YOSYS    = yosys

SRC_CORE = core/riscv_defines.vh \
           core/alu.v \
           core/regfile.v \
           core/decoder.v \
           core/branch_unit.v \
           core/hazard_unit.v \
           core/csr_unit.v \
           core/riscv_core.v

SRC_SOC  = soc/ram_controller.v \
           soc/uart.v \
           soc/clint_timer.v \
           soc/gpio.v \
           soc/vga_controller.v \
           soc/bus_interconnect.v \
           soc/soc_top.v

SIM_SRC  = sim/tb_soc.v $(SRC_CORE) $(SRC_SOC)

all: sim synth

firmware:
	$(MAKE) -C sim/firmware

sim: firmware sim/soc_sim.vvp
	cd sim && $(VVP) soc_sim.vvp

sim/soc_sim.vvp: $(SIM_SRC)
	$(IVERILOG) -Icore -Isoc -g2005 -o sim/soc_sim.vvp $(SIM_SRC)

sim-cache:
	$(IVERILOG) -g2012 -o sim/icache_sim.vvp core/icache.v sim/tb_icache.v
	cd sim && $(VVP) icache_sim.vvp

sim-branch:
	$(IVERILOG) -g2012 -o sim/branch_sim.vvp core/branch_predictor.v sim/tb_branch_predictor.v
	cd sim && $(VVP) branch_sim.vvp

# Alvos do Ecossistema LightRISCV (Prof. Ricardo Menotti)
sim-lightriscv:
	$(MAKE) -C ../lightriscv VERSION=COMPACT

sim-lightriscv-multi:
	$(MAKE) -C ../lightriscv VERSION=MULTI

sim-lightriscv-mono:
	$(MAKE) -C ../lightriscv VERSION=MONO

synth:
	cd fpga && $(YOSYS) -s synth_yosys.ys

clean:
	rm -f sim/soc_sim.vvp sim/soc_waveform.vcd soc_waveform.vcd sim/icache_sim.vvp
	$(MAKE) -C sim/firmware clean
	$(MAKE) -C ../lightriscv clean

.PHONY: all firmware sim sim-cache sim-branch sim-lightriscv sim-lightriscv-multi sim-lightriscv-mono synth clean
