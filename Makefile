PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
MANDIR = $(PREFIX)/share/man/man1
VERSION = 0.2.0
DISTDIR ?= sini-$(VERSION)
LINE_MAX ?= 4096
WARN_FLAGS = -Wall -Wextra -Wpedantic
PVS ?= pvs-studio-analyzer
PLOG ?= plog-converter
MKDIR ?= mkdir -p
PRINT_HELP ?= 1
PRINT_LONG_HELP ?= 1
SINI_STANDALONE ?= 1

FLAGS = -DSINI_VERSION=\"$(VERSION)\" -DLINE_MAX=$(LINE_MAX) \
		-DPRINT_LONG_HELP=$(PRINT_LONG_HELP) -DPRINT_HELP=$(PRINT_HELP) \
		-DSINI_STANDALONE=$(SINI_STANDALONE)

sini: main.c
	$(CC) -o $@ $^ $(FLAGS) $(CFLAGS) $(COV_FLAGS) $(WARN_FLAGS)

check:
	$(MAKE) -C tst check

$(DISTDIR):
	$(RM) -r $(DISTDIR)
	mkdir $(DISTDIR)
	cp LICENSE Makefile main.c sini.1 readme.md $(DISTDIR)
	mkdir $(DISTDIR)/tst
	cp tst/Makefile tst/folist tst/mtest.sh tst/test.ini tst/test.sh $(DISTDIR)/tst
	mkdir $(DISTDIR)/www
	cp www/custom.css www/footer.in www/gen-download-page.sh $(DISTDIR)/www
	cp www/header.in www/index.in www/index.md www/man2html.sh $(DISTDIR)/www
	cp www/post-process.sh $(DISTDIR)/www

dist: $(DISTDIR).tar.gz
$(DISTDIR).tar.gz: $(DISTDIR)
	tar czf $@ $<

$(DISTDIR).tar.bz2: $(DISTDIR)
	tar cjf $@ $<

$(DISTDIR).tar.xz: $(DISTDIR)
	tar cJf $@ $<

dist-all: $(DISTDIR).tar.gz $(DISTDIR).tar.bz2 $(DISTDIR).tar.xz

distclean: clean
	$(RM) -r sini-*

distcheck: $(DISTDIR).tar.gz
	$(RM) -r $(DISTDIR)
	tar xzf $(DISTDIR).tar.gz
	$(MAKE) -C $(DISTDIR) check
	$(MKDIR) $(DISTDIR)/install
	DESTDIR=install $(MAKE) -C $(DISTDIR) install
	$(MAKE) -C $(DISTDIR) distclean

clean:
	# main binary
	$(RM) sini
	# clang analyzer
	$(RM) main.plist
	# pvs studio analyzer
	$(RM) pvs-analyze
	$(RM) pvs-studio.log
	$(RM) strace_out
	$(MAKE) -C tst clean
	# www stuff
	$(RM) www/downloads.html
	$(RM) www/sini.1.html
	$(RM) -r www/out

install: sini
	install -m0755 -D $< $(DESTDIR)$(BINDIR)/$<
	install -m0644 -D sini.1 $(DESTDIR)$(MANDIR)/sini.1

uninstall:
	$(RM) $(DESTDIR)$(BINDIR)/sini
	$(RM) $(DESTDIR)$(MANDIR)/sini.1

www:
	./www/gen-download-page.sh
	./www/man2html.sh
	kursg -iwww -owww/out
	cd www && ./post-process.sh

main.plist: main.c
	clang --analyze main.c -o $@

clang-analyze: main.plist

# pvs-studio is pretty neat static code analyzer that nicely
# complement with clang's analyzer, and they have free licenses
# for open source projects/developers too!
# https://www.viva64.com/en/pvs-studio/
pvs-studio.log: clean
	$(PVS) trace -- make sini
	$(PVS) analyze -o $@

pvs-analyze: pvs-studio.log
	$(PLOG) -a "GA:1,2;64:1;OP:1,2,3;CS:1;MISRA:1,2" -t tasklist -o $@ $<

analyze: pvs-analyze clang-analyze

.PHONY: clean install uninstall check analyze www dist-all distclean distcheck dist
