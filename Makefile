#Copyright 2004, 2005, 2013 Dmitry Maksyoma
#Copying and distribution of this file, with or without modification,
#are permitted in any medium without royalty provided the copyright
#notice and this notice are preserved.

SHELL := /bin/bash

RELEASE_VERSION := 0.5
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
	@IFS=,; CUSTOM_HEADER='###CUSTOM SECTION';\
	src="$(SRC)"; src=($${src[@]}); unset IFS; i=0;\
	for dir in $(DEST); do\
	  mkdir -p $$dir;\
	  if [ "$$dir" = "$(ETC)" ]; then\
	    s=$${src[$$i]}; f=$${s#*/}; t="$$dir/$$f";\
	    if [ -f "$$t" ]; then\
	      ACTION="/^$$CUSTOM_HEADER/,\$$p";\
	      l=`sed -n "$$ACTION" $$t`;\
	      [ -z "$$l" ] && l="$$CUSTOM_HEADER\n"`cat $$t`;\
	    else\
	      l="$$CUSTOM_HEADER";\
	    fi;\
	    cat "$$s" > "$$t";\
	    grep -q MKAT_LIBPATH "$$t" 2>/dev/null || \
	      echo 'MKAT_LIBPATH=$(SHARE)' >> "$$t";\
	    echo "$$l" >> "$$t";\
	  else\
	    cp $${src[$$i]} $$dir;\
	  fi;\
	  let "i=$$i+1";\
	done;

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
	@echo "creating $(TARBALL)"
	if [ ! -e ../mkat ]; then \
	  CWD=$${PWD##*/}; \
	  trap 'rm -f ../mkat' EXIT; \
	  cd .. && ln -s "$$CWD" mkat && cd mkat; \
	fi; \
	tar -h --exclude .git --exclude test --exclude tools --exclude \*.swp --exclude TODO -czf $(TARBALL) -C .. mkat/
	-gpg -b $(TARBALL)

#I need this dependency so that changelog would be remade only when
#files it depends on change
changelog: $(shell find . -maxdepth 1 -type f -not -name changelog -not -name \*.swp)
	@git log --pretty=format:%cd%n%B --date=short | \
	  ./tools/git2cl > changelog && \
	  echo "This file is public domain" >> changelog

clean:
	-rm changelog

upload_savannah:
	curl -T $(TARBALL) ftp://savannah.gnu.org/incoming/savannah/mkat/
	curl -T $(TARBALL).sig ftp://savannah.gnu.org/incoming/savannah/mkat/

.PHONY: clean install uninstall dist
