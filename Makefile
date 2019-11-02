DESTDIR ?= /usr/local/bin
VERSION = 9999
LINE_MAX ?= 4096

FLAGS = -DSINI_VERSION=\"$(VERSION)\" -DLINE_MAX=$(LINE_MAX)

sini: main.c
	$(CC) -o $@ $^ $(FLAGS) $(CFLAGS)

check: sini
	./test.sh

clean:
	$(RM) -f sini

install: sini
	install $< $(DESTDIR)

uninstall:
	@echo "There is no uninstall target, try \`find /usr -name sini'"
	@echo "to locate binary and remove it manually"

.PHONY: clean install uninstall check
