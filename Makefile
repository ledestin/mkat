#destination directories
BIN := $(PREFIX)/usr/bin
MAN := $(PREFIX)/usr/local/man
MAN1 := $(MAN)1
MAN5 := $(MAN)5
DOC := $(PREFIX)/usr/local/share/doc/mkat
DEST := $(BIN) $(MAN1) $(MAN5) $(DOC)

#files to be copied
BIN_S := $(shell ls burn* mkat*)
MAN1_S := $(shell ls man/*.1)
MAN5_S := $(shell ls man/*.5)
DOC_S := README LICENSE
SRC := $(BIN_S),$(MAN1_S),$(MAN5_S),$(DOC_S)

install:
	@IFS=,; src="$(SRC)"; src=($${src[@]}); unset IFS; i=0;\
	for dir in $(DEST); do\
	  mkdir -p $$dir;\
	  cp $${src[$$i]} $$dir;\
	  let "i=$$i+1";\
	done;

uninstall:
	@IFS=,; src="$(SRC)"; src=($${src[@]}); unset IFS; i=0;\
	for dir in $(DEST); do\
	  files="`echo $${src[$$i]} | sed 's,[^/ ]*/,,g'`";\
	  cd $$dir && rm -f $${files[@]} && cd ~-;\
	  let "i=$$i+1";\
	done;
