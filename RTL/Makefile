PROJECT=A4092
PART=XC95144XL-10-TQ144
CABLE=usb21

#CPLDFITFLAGS=-loc on -slew slow -init low -terminate keeper  -unused ground -power std  -optimize speed -keepio
CPLDFITFLAGS=-loc on -slew fast -init low -terminate keeper  -unused float -power std  -optimize speed -keepio -exhaust -pterms 90

# Variants: A4092 (default), A4092c, A4770
VARIANTS = A4092 A4092c A4770

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
	-rm -f *.prj

flash:
	@echo "Usage: make flash VARIANT=<A4092|A4092c|A4770>"

# ---- Per-variant build (VARIANT is set) ----
else

WORKDIR=tmp-$(VARIANT)
DEFINES=

ifeq ($(VARIANT),A4092c)
  DEFINES += A4092c
else ifeq ($(VARIANT),A4770)
  DEFINES += A4770
else
  # A4092: respect USE_DIP_SWITCH option
  # default is DIP switch, not FLASH
  #USE_DIP_SWITCH ?= 1
  # default is FLASH
  USE_DIP_SWITCH ?= 0
  ifeq ($(USE_DIP_SWITCH),1)
    DEFINES += USE_DIP_SWITCH
  endif
endif

.PHONY:	all timing

all:	../Binary/$(VARIANT).jed timing

$(PROJECT).prj: *.v *.vh
	@rm -f $@
	@for src in $(filter %.v,$^); do echo "verilog work $$src" >> $@; done

$(WORKDIR)/$(PROJECT).ngc:	*.v *.vh $(PROJECT).prj
	@mkdir -p $(WORKDIR)
	@sed -r "s#^(-ofn).*#\1 ..\/$@#g;s#^(-ifn).*#\1 ../$(PROJECT).prj#g;s#^(-define).*#\1 {$(DEFINES)}#g" template.xst > $@.xst
	cd $(WORKDIR) && xst -ifn ../$@.xst -ofn $(PROJECT)-xst.log

$(WORKDIR)/%.ngd:	$(WORKDIR)/%.ngc $(PROJECT).ucf
	cd $(WORKDIR) && ngdbuild -p $(PART) -uc ../$(PROJECT).ucf ../$< ../$@

$(WORKDIR)/%.rpt $(WORKDIR)/%.vm6:	$(WORKDIR)/%.ngd $(PROJECT).ucf
	cd $(WORKDIR) && cpldfit $(CPLDFITFLAGS) -p $(PART) ../$< | egrep -v "^CS: block|^$$"
	cp $(WORKDIR)/$(PROJECT).rpt $(VARIANT).rpt

../Binary/$(VARIANT).jed:	$(WORKDIR)/$(PROJECT).vm6
	hprep6 -i $<
	@if [ "$(VARIANT)" != "$(PROJECT)" ]; then mv $(PROJECT).jed $(VARIANT).jed; fi
	mv $(VARIANT).jed $@

fit:	$(WORKDIR)/$(PROJECT).vm6

$(VARIANT).tim:	$(WORKDIR)/$(PROJECT).vm6
	cd $(WORKDIR) && taengine -l ../$(VARIANT).tim -f $(PROJECT)

timing:	$(VARIANT).tim

clean:
	-rm -rvf tmp-$(VARIANT)
	-rm -f $(VARIANT).tim $(VARIANT).rpt
	-rm -f *.prj

flash:	../Binary/$(VARIANT).jed
	@printf "setMode -bs\nsetCable -p $(CABLE)\nidentify\nassignfile -p 1 -file $<\nerase -p 1\nprogram -p 1\nverify -p 1\n" | LD_PRELOAD=/opt/Xilinx/usb-driver/libusb-driver.so impact -batch

endif
