BIN      := /usr/local/bin
LIB      := /usr/local/lib/urweb
INCLUDE  := /usr/local/include/urweb
SITELISP := /usr/local/share/emacs/site-lisp/urweb-mode

LIB_UR   := $(LIB)/ur
LIB_C    := $(LIB)/c

all: smlnj mlton c

.PHONY: all smlnj mlton c clean install

smlnj: src/urweb.cm
mlton: bin/urweb
c: clib/urweb.o clib/driver.o

clean:
	rm -f src/*.mlton.grm.* src/*.mlton.lex.* \
		src/urweb.cm src/urweb.mlb \
		clib/*.o
	rm -rf .cm src/.cm

clib/urweb.o: src/c/urweb.c
	gcc -O3 -I include -c src/c/urweb.c -o clib/urweb.o

clib/driver.o: src/c/driver.c
	gcc -O3 -I include -c src/c/driver.c -o clib/driver.o

src/urweb.cm: src/prefix.cm src/sources
	cat src/prefix.cm src/sources \
	>src/urweb.cm

src/urweb.mlb: src/prefix.mlb src/sources src/suffix.mlb
	cat src/prefix.mlb src/sources src/suffix.mlb \
	| sed 's/^\(.*\).grm$$/\1.mlton.grm.sig\n\1.mlton.grm.sml/' \
	| sed 's/^\(.*\).lex$$/\1.mlton.lex.sml/' \
	>src/urweb.mlb

%.mlton.lex: %.lex
	cp $< $@
%.mlton.grm: %.grm
	cp $< $@

%.mlton.lex.sml: %.mlton.lex
	mllex $<

%.mlton.grm.sig %.mlton.grm.sml: %.mlton.grm
	mlyacc $<

MLTON := mlton

ifdef DEBUG
	MLTON += -const 'Exn.keepHistory true'
endif

bin/urweb: src/urweb.mlb src/*.sig src/*.sml \
		src/urweb.mlton.lex.sml \
		src/urweb.mlton.grm.sig src/urweb.mlton.grm.sml
	$(MLTON) -output $@ src/urweb.mlb

install:
	cp bin/urweb $(BIN)/
	mkdir -p $(LIB_UR)
	cp lib/*.urs $(LIB_UR)/
	cp lib/*.ur $(LIB_UR)/
	mkdir -p $(LIB_C)
	cp clib/*.o $(LIB_C)/
	mkdir -p $(INCLUDE)
	cp include/*.h $(INCLUDE)/
	mkdir -p $(SITELISP)
	cp src/elisp/*.el $(SITELISP)/
