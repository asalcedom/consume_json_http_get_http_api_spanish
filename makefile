
BIN_LIB=ASALCEDO1
LIBLIST=$(BIN_LIB) LIBHTTP YAJL QGPL
SHELL=/QOpenSys/usr/bin/qsh

all: httpgetsp.sqlrpgle httpapisp.sqlrpgle

httpgetsp.sqlrpgle: httpgetspd.dspf
httpapisp.sqlrpgle: httpgetspd.dspf

%.sqlrpgle:
	system -s "CHGATR OBJ('./qrpglesrc/$*.sqlrpgle') ATR(*CCSID) VALUE(1252)"
	liblist -a $(LIBLIST);\
	system "CRTSQLRPGI OBJ($(BIN_LIB)/$*) SRCSTMF('./qrpglesrc/$*.sqlrpgle') COMMIT(*NONE) DBGVIEW(*SOURCE) OPTION(*EVENTF)"

%.dspf:
	-system -qi "CRTSRCPF FILE($(BIN_LIB)/QDDSSRC) RCDLEN(112)"
	system "CPYFRMSTMF FROMSTMF('./qddssrc/$*.dspf') TOMBR('/QSYS.lib/$(BIN_LIB).lib/QDDSSRC.file/$*.mbr') MBROPT(*REPLACE)"
	system -s "CRTDSPF FILE($(BIN_LIB)/$*) SRCFILE($(BIN_LIB)/QDDSSRC) SRCMBR($*)"