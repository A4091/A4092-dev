# Behavioral RTL testbench suite (iverilog). Run: make
RTL := ..
IV  := iverilog -g2012 -I.
TBS := tb_sidregister tb_buffercontrol tb_parallelrom tb_interrupthandling \
       tb_autoconfig tb_scsiaccess tb_dmamaster tb_dmaarbiter tb_spirom

tb_sidregister_SRC      := sidregister.v
tb_buffercontrol_SRC    := buffercontrol.v
tb_parallelrom_SRC      := parallelrom.v
tb_interrupthandling_SRC:= interrupthandling.v
tb_autoconfig_SRC       := autoconfig.v
tb_scsiaccess_SRC       := scsiaccess.v
tb_dmamaster_SRC        := dmamaster.v
tb_dmaarbiter_SRC       := dmaarbiter.v
tb_spirom_SRC           := spirom.v

.PHONY: all clean $(TBS)
all: $(TBS)
	@echo "all testbenches done"

$(TBS):
	@$(IV) -o /tmp/$@.vvp $@.v $(RTL)/$($@_SRC) && vvp -n /tmp/$@.vvp

clean:
	-rm -f /tmp/tb_*.vvp

TOPSRC := ../A4092.v ../autoconfig.v ../buffercontrol.v ../dmaarbiter.v ../dmamaster.v ../scsiaccess.v ../interrupthandling.v ../sidregister.v ../spirom.v
.PHONY: top top-a4092 top-a4770
top: top-a4092 top-a4770
top-a4092:
	@iverilog -g2012 -DA4092c -I. -o /tmp/z3_92.vvp tb_a4092_zorro3.v $(TOPSRC) && vvp -n /tmp/z3_92.vvp
top-a4770:
	@iverilog -g2012 -DA4770  -I. -o /tmp/z3_77.vvp tb_a4092_zorro3.v $(TOPSRC) && vvp -n /tmp/z3_77.vvp
