#Copyright 2004, 2005 Dmitry Maksyoma
#Copying and distribution of this file, with or without modification,
#are permitted in any medium without royalty provided the copyright
#notice and this notice are preserved.

RELEASE_VERSION := 0.3
RELEASE_DIR ?= ..
TARBALL := $(RELEASE_DIR)/mkat_$(RELEASE_VERSION).tgz

#destination directories
BIN := $(PREFIX)/usr/local/bin
ETC := $(PREFIX)/etc
MAN := $(PREFIX)/usr/local/man
MAN1 := $(MAN)1
MAN5 := $(MAN)5
DOC := $(PREFIX)/usr/local/share/doc/mkat
SHARE := $(PREFIX)/usr/local/share/mkat
DEST := $(BIN) $(ETC) $(MAN1) $(MAN5) $(DOC) $(SHARE)

#files to be copied
BIN_S := $(shell ls burn* mkat*)
ETC_S := examples/mkatrc
MAN1_S := $(shell ls man/*.1)
MAN5_S := $(shell ls man/*.5)
DOC_S := README LICENSE
SHARE_S := helpers.sh
SRC := $(BIN_S),$(ETC_S),$(MAN1_S),$(MAN5_S),$(DOC_S),$(SHARE_S)

install:
	@IFS=,; src="$(SRC)"; src=($${src[@]}); unset IFS; i=0;\
	for dir in $(DEST); do\
	  mkdir -p $$dir;\
	  cp $${src[$$i]} $$dir;\
	  let "i=$$i+1";\
	done;
	@grep -q MKAT_LIBPATH /etc/mkatrc 2>/dev/null || \
	  echo MKAT_LIBPATH=$(SHARE) >> /etc/mkatrc

uninstall:
	@IFS=,; src="$(SRC)"; src=($${src[@]}); unset IFS; i=0;\
	for dir in $(DEST); do\
	  files="`echo $${src[$$i]} | sed 's,[^/ ]*/,,g'`";\
	  cd $$dir && rm -rf $${files[@]} && cd ~-;\
	  let "i=$$i+1";\
	done;
	@rmdir $(DOC) $(SHARE)

#make distribution tarball
dist: changelog
	echo $(TARBALL)
	tar --exclude CVS --exclude test --exclude \*.swp --exclude TODO -czf $(TARBALL) -C .. mkat/
	-gpg --default-key 2FFCC6ED -b $(TARBALL)

#I need this dependency so that changelog would be remade only when
#files it depends on change
changelog: $(shell find . -type f -maxdepth 1 -not -name changelog -not -name \*.swp)
	@-cvs2cl -t -R '^[^#]+$$$$' --stdout > changelog && \
	echo "This file is public domain" >> changelog

clean:
	-rm changelog

deploy:
	scp $(TARBALL) monster.amur.ru:~/public_html/mkat/files
	scp README monster.amur.ru:~/public_html/mkat/files

upload_savannah:
	curl -T $(TARBALL) ftp://savannah.gnu.org/incoming/savannah/mkat/
	curl -T $(TARBALL).sig ftp://savannah.gnu.org/incoming/savannah/mkat/

.PHONY: clean install uninstall dist deploy
