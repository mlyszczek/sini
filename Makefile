DESTDIR ?= /usr/local/bin
VERSION = 9999
LINE_MAX ?= 4096
COVERAGE ?= n
LCOV ?= lcov
GENHTML ?= genhtml
WARN_FLAGS = -Wall -Wextra -Wpedantic
PVS ?= pvs-studio-analyzer
PLOG ?= plog-converter

FLAGS = -DSINI_VERSION=\"$(VERSION)\" -DLINE_MAX=$(LINE_MAX)

ifeq ($(COVERAGE),y)
COV_FLAGS = --coverage -lgcov
endif

sini: main.c
	$(CC) -o $@ $^ $(FLAGS) $(CFLAGS) $(COV_FLAGS) $(WARN_FLAGS)

check: sini
	./test.sh

clean:
	# main binary
	$(RM) sini
	# gcov stuff
	$(RM) coverage.info
	$(RM) main.gcda
	$(RM) main.gcno
	$(RM) -r ./coverage
	# clang analyzer
	$(RM) main.plist
	# pvs studio analyzer
	$(RM) pvs-analyze
	$(RM) pvs-studio.log
	$(RM) strace_out

install: sini
	install $< $(DESTDIR)

uninstall:
	@echo "There is no uninstall target, try \`find /usr -name sini'"
	@echo "to locate binary and remove it manually"

coverage: check
	$(LCOV) --directory . --capture --output-file coverage.info --no-checksum --compat-libtool
	LANG=C $(GENHTML) --prefix . --output-directory coverage --title "Code Coverage" --legend --show-details coverage.info

main.plist:
	clang --analyze main.c -o $@

analyze: main.plist

# pvs-studio is pretty neat static code analyzer that nicely
# complement with clang's analyzer, and they have free licenses
# for open source projects/developers too!
# https://www.viva64.com/en/pvs-studio/
pvs-studio.log: clean
	$(PVS) trace -- make sini
	$(PVS) analyze -o $@

pvs-analyze: pvs-studio.log
	$(PLOG) -a "GA:1,2;64:1;OP:1,2,3;CS:1;MISRA:1,2" -t tasklist -o $@ $<

.PHONY: clean install uninstall check analyze
