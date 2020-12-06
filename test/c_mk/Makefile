CC := $(VBCC)/bin/vbccirre
AS := $(IRREBIN)/irre-asm

CFILES := $(shell find . -name '*.c')
export CASMFILES := $(CFILES:.c=.casm)
# export OFILES := $(CFILES:.c=.o) $(SFILES:.s=.o)
BINOUT := "prog_out.ire"

.PHONY: clean

all: $(BINOUT)

$(BINOUT): $(CASMFILES)
	$(AS) -m exe $^ $@

%.casm: %.c
	@echo $(notdir $<)
	$(CC) -c99 -default-main $< -o=$@

clean:
	# casm outputs
	@rm -rf *.casm
	@rm -rf $(BINOUT)