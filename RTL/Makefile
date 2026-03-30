PROJECT=A4092
PART=XC95144XL-10-TQ144
CABLE=usb21
PROJECT_FILE=$(PROJECT).xise
PROJECT_INPUTS=$(PROJECT_FILE) $(PROJECT).ucf $(wildcard *.v) $(wildcard *.vh)

# Variants: A4092 (SPI ROM, no DIP switch), A4770
BASE_VARIANTS = A4092 A4770
BUSTER9_VARIANTS = $(addsuffix _Buster9,$(BASE_VARIANTS))
VARIANTS = $(BASE_VARIANTS) $(BUSTER9_VARIANTS)

# ---- Top-level targets (no VARIANT set) ----
ifndef VARIANT

.PHONY:	all clean timing $(VARIANTS)

all:	$(VARIANTS)

$(VARIANTS):
	$(MAKE) VARIANT=$@

timing:
	@for v in $(VARIANTS); do $(MAKE) VARIANT=$$v timing; done

clean:
	-rm -rvf tmp-*
	-rm -f *.tim *.rpt
	-rm -f *.prj *.gise

flash:
	@echo "Usage: make flash VARIANT=<A4092|A4770|A4092_Buster9|A4770_Buster9>"

# ---- Per-variant build (VARIANT is set) ----
else

WORKDIR=tmp-$(VARIANT)
BASE_VARIANT=$(patsubst %_Buster9,%,$(VARIANT))
DEFINES=

ifneq ($(VARIANT),$(BASE_VARIANT))
  DEFINES += BUSTER09
endif

ifeq ($(BASE_VARIANT),A4092)
  DEFINES += A4092c
else ifeq ($(BASE_VARIANT),A4770)
  DEFINES += A4770
endif

.PHONY:	all timing

all:	../Binary/$(VARIANT).jed timing

$(WORKDIR)/.project-ready: $(PROJECT_INPUTS) run_ise_project.tcl Makefile
	@mkdir -p $(WORKDIR)
	@cp $(PROJECT_FILE) $(WORKDIR)/
	@for src in $(filter-out $(PROJECT_FILE),$(PROJECT_INPUTS)); do \
		ln -sfn ../$$src $(WORKDIR)/$$src; \
	done
	@touch $@

$(WORKDIR)/$(PROJECT).jed $(WORKDIR)/$(PROJECT).vm6 $(WORKDIR)/$(PROJECT).rpt &: $(WORKDIR)/.project-ready
	cd $(WORKDIR) && xtclsh ../run_ise_project.tcl $(PROJECT).xise "Implement Design" "$(DEFINES)"
	test -f $(WORKDIR)/$(PROJECT).jed
	test -f $(WORKDIR)/$(PROJECT).vm6
	test -f $(WORKDIR)/$(PROJECT).rpt
	cp $(WORKDIR)/$(PROJECT).rpt $(VARIANT).rpt

../Binary/$(VARIANT).jed:	$(WORKDIR)/$(PROJECT).jed
	@mkdir -p ../Binary
	cp $< $@

fit:	$(WORKDIR)/$(PROJECT).vm6

$(VARIANT).tim:	$(WORKDIR)/$(PROJECT).vm6
	cd $(WORKDIR) && taengine -l ../$(VARIANT).tim -f $(PROJECT)

timing:	$(VARIANT).tim

clean:
	-rm -rvf tmp-$(VARIANT)
	-rm -f $(VARIANT).tim $(VARIANT).rpt
	-rm -f *.prj *.gise

flash:	../Binary/$(VARIANT).jed
	@printf "setMode -bs\nsetCable -p $(CABLE)\nidentify\nassignfile -p 1 -file $<\nerase -p 1\nprogram -p 1\nverify -p 1\n" | LD_PRELOAD=/opt/Xilinx/usb-driver/libusb-driver.so impact -batch

endif
