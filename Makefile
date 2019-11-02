DESTDIR ?= /usr/local/bin
VERSION = 9999
LINE_MAX ?= 4096
COVERAGE ?= n
LCOV ?= lcov
GENHTML ?= genhtml
WARN_FLAGS = -Wall -Wextra -Wpedantic

FLAGS = -DSINI_VERSION=\"$(VERSION)\" -DLINE_MAX=$(LINE_MAX)

ifeq ($(COVERAGE),y)
COV_FLAGS = --coverage -lgcov
endif

sini: main.c
	$(CC) -o $@ $^ $(FLAGS) $(CFLAGS) $(COV_FLAGS) $(WARN_FLAGS)

check: sini
	./test.sh

clean:
	$(RM) sini
	$(RM) coverage.info
	$(RM) main.gcda
	$(RM) main.gcno
	$(RM) main.plist
	$(RM) -r ./coverage

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

.PHONY: clean install uninstall check analyze
