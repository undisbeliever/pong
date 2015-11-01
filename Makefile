ROM_NAME    = Pong
CONFIG_FILE = src/LOROM_1MBit_copyright.cfg

SRC         = $(wildcard src/*.s)
INCLUDES    = $(wildcard src/*.h src/*.inc)

BINARY      = bin/$(ROM_NAME).sfc

OBJECTS     = $(patsubst src/%.s,obj/%.o,$(SRC))

# Disable Builtin rules
.SUFFIXES:
.DELETE_ON_ERROR:
MAKEFLAGS += --no-builtin-rules

.PHONY: all
all: dirs $(BINARY)

$(BINARY): $(OBJECTS)
	ld65 -vm -m $(@:.sfc=.memlog) -C $(CONFIG_FILE) -o $@ $^
	cd bin/ && ucon64 --snes --nhd --chk $(notdir $@)

$(OBJECTS): $(INCLUDES) $(CONFIG_FILE) Makefile
obj/%.o: src/%.s
	ca65 -I src -o $@ $<

obj/ui.o: resources/tiles.4bpp resources/tiles.clr

resources/tiles.4bpp resources/tiles.clr: resources/tiles.pcx
	pcx2snes -n -s8 -c16 resources/tiles
	mv resources/tiles.pic resources/tiles.4bpp

.PHONY: dirs
dirs: bin/ obj/

bin/ obj/:
	mkdir -p $@


.PHONY: clean
clean:
	$(RM) bin/$(BINARY) $(OBJECTS)
	$(RM) resources/tiles.4bpp resources/tiles.clr

