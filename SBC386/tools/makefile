CC=gcc
OUTPUT=-o
RM=rm -f
CP=cp
EXE2ROM=exe2rom
HEX2BIN=hex2bin
BIN2HEX=bin2hex
COPT=copt
TRUNC=trunc

all:	$(EXE2ROM) $(HEX2BIN) $(BIN2HEX) $(TRUNC) $(COPT)

$(EXE2ROM): exe2rom.c mytypes.h
	$(CC) $(OUTPUT) $@ $@.c

$(HEX2BIN): hex2bin.c mytypes.h
	$(CC) $(OUTPUT) $@ $@.c

$(BIN2HEX): $(HEX2BIN)
	$(CP) $(HEX2BIN) $(BIN2HEX)

$(COPT):  copt.c
	$(CC) $(OUTPUT) $@ $@.c


$(TRUNC): trunc.c
	$(CC) $(OUTPUT) $@ $@.c

clean:
	$(RM) $(EXE2ROM)
	$(RM) $(HEX2BIN)
	$(RM) $(BIN2HEX)
	$(RM) $(COPT)
	$(RM) $(TRUNC)
