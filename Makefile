DESTDIR ?= /usr/local
VERSION = 9999
LINE_MAX ?= 4096
WARN_FLAGS = -Wall -Wextra -Wpedantic
PVS ?= pvs-studio-analyzer
PLOG ?= plog-converter

FLAGS = -DSINI_VERSION=\"$(VERSION)\" -DLINE_MAX=$(LINE_MAX)

sini: main.c
	$(CC) -o $@ $^ $(FLAGS) $(CFLAGS) $(COV_FLAGS) $(WARN_FLAGS)

check:
	$(MAKE) -C tst check

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

install: sini
	install -m0755 -D $< $(DESTDIR)/bin/$<
	install -m0644 -D sini.1 $(DESTDIR)/share/man/man1/sini.1

uninstall:
	$(RM) $(DESTDIR)/bin/sini
	$(RM) $(DESTDIR)/share/man/man1/sini.1

main.plist:
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

.PHONY: clean install uninstall check analyze
