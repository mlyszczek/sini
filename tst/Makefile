OVERAGE ?= n
LCOV ?= lcov
GENHTML ?= genhtml

ifeq ($(COVERAGE),y)
COV_FLAGS = --coverage -lgcov
endif

fo.c:
	fogen -l folist

fo.o: fo.c
	$(CC) -fPIC -c $^ -o $@ $(CFLAGS)

libfo.so: fo.o
	$(CC) -shared -fPIC -Wl,-soname,$@.1 -Wl,-init,fo_init -o $@ fo.o -lc -ldl

sini: ../main.c libfo.so
	$(CC) -o $@ $< $(CFLAGS) $(COV_FLAGS) $(WARN_FLAGS) -L. -lfo

check: sini libfo.so
	./test.sh

coverage: clean check
	$(LCOV) --directory . --capture --output-file coverage.info --no-checksum --compat-libtool
	LANG=C $(GENHTML) --prefix . --output-directory coverage --title "Code Coverage" --legend --show-details coverage.info

clean:
	# main binary
	$(RM) sini
	# gcov stuff
	$(RM) coverage.info
	$(RM) main.gcda
	$(RM) main.gcno
	$(RM) -r ./coverage
	# fogen stuff
	$(RM) fo.c
	$(RM) fo.h
	$(RM) fo.o
	$(RM) libfo.so

.PHONY: check clean coverage
