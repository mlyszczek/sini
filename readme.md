[kursg-meta]: # (order: 1)

About
=====

**sini** - shell ini, it simply allows you to manipulate dos ini files from
command line or shell script. Both read and store (non destructive) operations
are supported.

Usage
=====

Full documentation about usage is available in [sini][1](1) manual page, but
here are quick examples to get a quick grasp what [sini][1](1) does.

~~~
# read output-dir that is in no-section... section
$ sini get termsend.ini output-dir
/var/lib/termsend

# get can be omited, read field ssl from section [port]
$ sini termsend.ini port ssl
1339

# file path can be exported and then get info passing only ini object
$ export SINI_FILE=termsend.ini
$ ./sini ssl key-file
/etc/termsend/termsend.key

# ini can be passed via stdin (pipes)
$ cat termsend.ini | ./sini - max filesize
10485760
~~~

[sini][1](1) also supports modifying and adding new sections and fields
and does *not* destroy file in any way.

~~~
$ cat test.ini

# set empty new object in empty test.ini file
$ sini set test.ini user termsend
$ cat test.ini
user = termsend

# add new object into non-existing section
$ sini set test.ini port ssl 1339
$ cat test.ini
user = termsend
[port]
ssl = 1339

# sini works in non-destructive way, so if we have ini with comments,
# modifying fields do not destroy them, or anything
$ cat test.ini
; user that will run daemon
user = termsend

; port definitions
[port]
; ssl listen port
ssl = 1339

; non-ssl listen port
plain = 1337
$ sini set test.ini port ssl 443
$ cat test.ini
; user that will run daemon
user = termsend

; port definitions
[port]
; ssl listen port
ssl = 443

; non-ssl listen port
plain = 1337
~~~

Compilation
===========

Just run **make** and to install **make install**. [sini][1](1) is a valid
**ANSI** program, so it should work and compile anywhere, where C compiler is.

It's also a single file program, so you can also manually build it just by
calling **cc** program: **cc main.c -o sini**.

Compile time options
====================

Compilation can be tuned to save program an stack memory - this is usefull
for small embedded system where couple of hundred of bytes is a lot.

SINI_VERSION (default: 9999)
----------------------------

No a memory saving field, but it's still there. This string will be printed
when '-v' is specified. This is set to proper value when building with
**make**.

PRINT_HELP (default: 1)
-----------------------

If set to 0, none of help strings will be compiled in, -h won't print help,
and will just exit(0). This saves around 1kB of program memory.

PRINT_LONG_HELP (default: 1)
----------------------------

If long help is not needed (with description and examples) one can disable
it by setting this to 0. In that case PRINT_HELP will add around 150bytes
of program memory, and -h will print very brief usage info. Enabling this
adds 800bytes of program memory.

LINE_MAX (default: 4096)
------------------------

[sini][1](1) does not use any dynamic allocations, so there is max line
limit imposed. By default it is 4096 bytes, so if you have ini files that
are bigger than this, you can increase this value during compilation,
but it is more probable you will decrease it on embedded system.
This value directly affect how much stack memory will be used as
program will allocate LINE_MAX bytes on stack each time it is called.

Comments ignore LINE_MAX limit, so you can have nice and short key=value
entries and still take advantage of full 78character wide comments. So
if LINE_MAX is 16, following ini file is fully compatible:

~~~
; a very long comment that exceeds configured 16 bytes
; line limit size, sini really couldn't care less about
; comments
[section]
key = value
; many letters, such wow, much longevity, so ignoring
; stack so precious, savest
next key = 5
~~~

SINI_STANDALONE (default: 1)
----------------------------

Flag for embedded systems that do not support binary loading. When
this is set to 1, standard main() function will be defined, but if
you set this to 0, sini_main() will be used instead allowing you
to call program as an ordinary function.

ini specification
=================

Since **ini** does not have any official specification, all
assumptions made by program can be found in [sini][1](1) manual page.

License
=======

Program is licensed under BSD 2-clause license. See LICENSE file for details.

Contact
=======

You can send any bugs or feature requests to:
Michał Łyszczek <michal.lyszczek@bofc.pl>

See also
========
* [mtest](https://mtest.bofc.pl) macro unit test framework for **c/c++**
* [git repository](https://git.bofc.pl/sini) to browse sources online
* [pvs studio](https://www.viva64.com/en/pvs-studio) static code analyzer with
	free licenses for open source projects

[1]: https://sini.bofc.pl/sini.1.html
