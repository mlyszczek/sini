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
# read .output-dir that is in no-section... section
$ sini get termsend.ini .output-dir
/var/lib/termsend

# get can be omited, read field ssl from section [port]
$ sini termsend.ini port.ssl
1339

# file path can be exported and then get info passing only ini object
$ export SINI_FILE=termsend.ini
$ ./sini ssl.key-file
/etc/termsend/termsend.key

# ini can be passed via stdin (pipes)
$ cat termsend.ini | ./sini - max.filesize
10485760
~~~

[sini][1](1) also supports modifying and adding new sections and fields
and does *not* destroy file in any way.

~~~
$ cat test.ini

# set empty new object in empty test.ini file
$ sini set test.ini .user termsend
$ cat test.ini
user = termsend

# add new object into non-existing section
$ sini set test.ini port.ssl 1339
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
$ sini set test.ini port.ssl 443
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

Limitations
===========

[sini][1](1) does not use any dynamic allocations, so there is max line limit
imposed. By default it is 4096 bytes, so if you have ini files that are bigger
than this, you can increase this value during compilation by running

~~~
make LINE_MAX=65535
~~~

But if your lines are longer than 4096, than you really shouldn't be using
ini files, but something more apropriate.

For embedded, it would be wise to lower this to even 128, as this determines
how much stack memory will be taken during execution.

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
