#!/bin/sh
## ==========================================================================
#   Licensed under BSD 2clause license See LICENSE file for more information
#   Author: Michał Łyszczek <michal.lyszczek@bofc.pl>
## ==========================================================================


. ./mtest.sh
sini=../sini
test_ini="./test.ini"
tmp_ini="./tmp.ini"

out=
err=
workfile=

## ==========================================================================
#               ____                     __   _
#              / __/__  __ ____   _____ / /_ (_)____   ____   _____
#             / /_ / / / // __ \ / ___// __// // __ \ / __ \ / ___/
#            / __// /_/ // / / // /__ / /_ / // /_/ // / / /(__  )
#           /_/   \__,_//_/ /_/ \___/ \__//_/ \____//_/ /_//____/
#
## ==========================================================================


## ==========================================================================
#   Generate random string. Function appends '\n' automatically, to generate
#   string with 128 byte (including \n") pass 127 as first argument.
#
#   $1 - number of characters to generate (excluding '\n'
## ==========================================================================


randstr()
{
	cat /dev/urandom | tr -dc 'a-zA-Z0-9' | tr -d '\0' | fold -w $1 | head -n 1
}


mt_prepare_test()
{
	out=$(mktemp)
	err=$(mktemp)
	workfile=$(mktemp)
}

mt_cleanup_test()
{
	rm -f ${out}
	rm -f ${err}
	rm -f ${workfile}
}

## ==========================================================================
#                           __               __
#                          / /_ ___   _____ / /_ _____
#                         / __// _ \ / ___// __// ___/
#                        / /_ /  __/(__  )/ /_ (__  )
#                        \__/ \___//____/ \__//____/
#
## ==========================================================================


## ==========================================================================
## ==========================================================================


get_good()
{
	object="${1}"
	value="${2}"
	mode="${3}"

	case ${mode} in
		normal)
			pout="$(${sini} get ${test_ini} "${object}")"
			;;
		envvar)
			pout="$(SINI_FILE=${test_ini} ${sini} get "${object}")"
			;;
		pipein)
			pout="$(cat ${test_ini} | ${sini} get - "${object}")"
			;;
	esac
	mt_fail "[ ${?} -eq 0 ]"
	mt_fail "[ \"x${pout}\" = \"x${value}\" ]"
}


## ==========================================================================
## ==========================================================================


arg_error()
{
	args=${1}
	msg=${2}

	msg+=", check \`sini -h'"
	eval ${sini} ${args} >${out} 2>${err}
	mt_fail "[ ${?} -eq 1 ]"

	stdout=$(cat ${out})
	stderr="$(cat ${err})"
	mt_fail "[ -z \"${stdout}\" ]"

	mt_fail "[ $(tail -c1 ${err} | wc -l) -eq 1 ]"
	if [ "${stderr}" != "${msg}" ]; then
		mt_fail "test -z 'stderr != msg'"
		echo err: "${stderr}"
		echo exp: "${msg}"
	fi
}


## ==========================================================================
## ==========================================================================


object_not_found()
{
	${sini} ${test_ini} nonexisting.object >${out} 2>${err}
	mt_fail "[ ${?} -eq 2 ]"

	mt_fail "[ $(stat --format=%s ${out}) -eq 0 ]"
	mt_fail "[ $(stat --format=%s ${err}) -eq 0 ]"
}


## ==========================================================================
## ==========================================================================


object_not_found_in_matchin_section()
{
	${sini} ${test_ini} section.does-not-exist >${out} 2>${err}
	mt_fail "[ ${?} -eq 2 ]"

	mt_fail "[ $(stat --format=%s ${out}) -eq 0 ]"
	mt_fail "[ $(stat --format=%s ${err}) -eq 0 ]"
}


## ==========================================================================
## ==========================================================================


object_not_found_in_last_matchin_section()
{
	${sini} ${test_ini} section-ind-space.does-not-exist >${out} 2>${err}
	mt_fail "[ ${?} -eq 2 ]"

	mt_fail "[ $(stat --format=%s ${out}) -eq 0 ]"
	mt_fail "[ $(stat --format=%s ${err}) -eq 0 ]"
}


## ==========================================================================
## ==========================================================================


get_with_max_path()
{
	# crude test assuming PAH_MAX is 4096 and NAME_LEN 255

	path="/tmp/$(randstr 255)"
	path_to_rm=${path}
	for i in $(seq 1 1 14); do
		path+="/$(randstr 255)"
	done

	path+="/$(randstr 235)"
	mkdir -p ${path}
	path+="/cfg.ini"
	echo "name=value" > ${path}

	${sini} set ${path} .name value1
	mt_fail "[ ${?} -eq 0 ]"
	mt_fail "[ \"$(cat ${path})\" = \"name = value1\" ]"

	rm -rf "${path_to_rm}"
}


## ==========================================================================
## ==========================================================================


get_with_max_name()
{
	# crude test assuming PAH_MAX is 4096 and NAME_LEN 255

	path="/tmp/$(randstr 247)"
	echo "name=value" > ${path}

	${sini} set ${path} .name value1
	mt_fail "[ ${?} -eq 0 ]"
	mt_fail "[ \"$(cat ${path})\" = \"name = value1\" ]"

	rm -rf "${path}"
}

## ==========================================================================
## ==========================================================================


get_with_too_big_path()
{
	# crude test assuming PAH_MAX is 4096 and NAME_LEN 255

	path="/tmp/$(randstr 255)"
	path_to_rm=${path}
	for i in $(seq 1 1 14); do
		path+="/$(randstr 255)"
	done

	path+="/$(randstr 236)"
	mkdir -p ${path}
	path+="/cfg.ini"
	echo "name=value" > ${path}

	${sini} set ${path} .name value1 >${out} 2>${err}
	mt_fail "[ ${?} -eq 1 ]"
	mt_fail "[ \"$(cat ${path})\" = \"name=value\" ]"
	mt_fail "[ \"$(cat ${err})\" = \"can't create temp file, path to <file> too large\" ]"
	mt_fail "[ -z \"$(cat ${out})\" ]"

	rm -rf "${path_to_rm}"
}


## ==========================================================================
## ==========================================================================


get_with_too_big_name()
{
	# crude test assuming PAH_MAX is 4096 and NAME_LEN 255

	path="/tmp/$(randstr 248)"
	echo "name=value" > ${path}

	${sini} set ${path} .name value1 >${out} 2>${err}
	mt_fail "[ ${?} -eq 1 ]"
	mt_fail "[ \"$(cat ${path})\" = \"name=value\" ]"
	mt_fail "[ \"$(cat ${err})\" = \"can't create temp file, <file> name too large\" ]"
	mt_fail "[ -z \"$(cat ${out})\" ]"

	rm -rf "${path}"
}
## ==========================================================================
## ==========================================================================


do_invalid()
{
	action=${1}
	printf "${2}\n" > ${workfile}
	object=${3}
	error=${4}

	${sini} ${action} ${workfile} ${object} value >${out} 2>${err}
	mt_fail "[ ${?} -eq 1 ]"

	stdout="$(cat ${out})"
	mt_fail "[ -z \"${stdout}\" ]"

	stderr=$(cat ${err})
	mt_fail "[ $(tail -c1 ${err} | wc -l) -eq 1 ]"
	if [ "${stderr}" != "${error}" ]; then
		mt_fail "test -z 'stderr != error'"
		echo err: "${stderr}"
		echo exp: "${error}"
	fi
}


## ==========================================================================
## ==========================================================================


set_good()
{
	begin=${1}
	expect=${2}
	object=${3}
	value=${4}
	mode=${5}

	expectfile=$(mktemp)

	printf "${expect}\n" > ${expectfile}
	printf "${begin}" > ${workfile}
	if [ -n "${begin}" ]; then
		printf "\n" >> ${workfile}
	fi

	case ${mode} in
		normal)
			${sini} set ${workfile} "${object}" "${value}"
			ret=${?}
			;;

		envvar)
			SINI_FILE=${workfile} ${sini} set "${object}" "${value}"
			ret=${?}
			;;

		pipein)
			tmpfile=$(mktemp)
			cat "${workfile}" | ${sini} set - "${object}" "${value}" >${tmpfile}
			ret=${?}
			mv ${tmpfile} ${workfile}
			;;
	esac

	mt_fail "[ ${ret} -eq 0 ]"
	diff ${workfile} ${expectfile}
	mt_fail "[ ${?} -eq 0 ]"

	rm ${expectfile}
}


## ==========================================================================
## ==========================================================================


print_help()
{
	eval ${sini} -h >${out} 2>${err}
	mt_fail "[ ${?} -eq 0 ]"

	stderr="$(cat ${err})"
	mt_fail "[ -z \"${stderr}\" ]"
	mt_fail "grep 'sini - shell ini file manipulator' ${out} >/dev/null"
}


## ==========================================================================
## ==========================================================================


print_version()
{
	eval ${sini} -v >${out} 2>${err}
	mt_fail "[ ${?} -eq 0 ]"

	stderr="$(cat ${err})"
	mt_fail "[ -z \"${stderr}\" ]"
	mt_fail "grep -E 'sini v[0-9]' ${out} >/dev/null"
}


## ==========================================================================
## ==========================================================================


line_too_big()
{
	max_line=$(strings ${sini} | grep "line longer than" | grep -Eo "[0-9]+")
	name=$(randstr $((max_line / 2 + 100)))
	value=$(randstr $((max_line / 2 + 100)))
	echo $name = $value > ${workfile}

	${sini} ${workfile} .anything >${out} 2>${err}
	mt_fail "[ ${?} -eq 1 ]"
	stdout="$(cat ${out})"
	mt_fail "[ -z \"${stdout}\" ]"
	error=$(cat ${err})
	mt_fail "[ \"${error}\" = \"line longer than ${max_line}. Sorry.\" ]"
}


## ==========================================================================
## ==========================================================================


section_line_too_big()
{
	max_line=$(strings ${sini} | grep "line longer than" | grep -Eo "[0-9]+")
	section=$(randstr $((max_line + 100)))
	echo "[${section}]" > ${workfile}
	echo "name = value" >> ${workfile}

	${sini} ${workfile} sec.anything >${out} 2>${err}
	mt_fail "[ ${?} -eq 1 ]"
	stdout="$(cat ${out})"
	mt_fail "[ -z \"${stdout}\" ]"
	error=$(cat ${err})
	mt_fail "[ \"${error}\" = \"line longer than ${max_line}. Sorry.\" ]"
}


## ==========================================================================
## ==========================================================================


comment_line_too_big()
{
	max_line=$(strings ${sini} | grep "line longer than" | grep -Eo "[0-9]+")
	comment=$(randstr $((max_line + 100)))
	echo "; ${comment}" > ${workfile}
	echo "name = value" >> ${workfile}

	${sini} ${workfile} .anything >${out} 2>${err}
	mt_fail "[ ${?} -eq 1 ]"
	stdout="$(cat ${out})"
	mt_fail "[ -z \"${stdout}\" ]"
	error=$(cat ${err})
	mt_fail "[ \"${error}\" = \"line longer than ${max_line}. Sorry.\" ]"
}


## ==========================================================================
## ==========================================================================


no_such_file()
{
	${sini} non-existing-file .anything >${out} 2>${err}
	mt_fail "[ ${?} -eq 1 ]"
	stdout="$(cat ${out})"
	mt_fail "[ -z \"${stdout}\" ]"
	error=$(cat ${err})
	mt_fail "[ \"${error}\" = \"failed to open <file>: No such file or directory\" ]"
}

## ==========================================================================
## ==========================================================================


read_access()
{
	echo "name = value" > ${workfile}
	chmod 200 ${workfile}

	${sini} ${workfile} .anything >${out} 2>${err}
	mt_fail "[ ${?} -eq 1 ]"
	stdout="$(cat ${out})"
	mt_fail "[ -z \"${stdout}\" ]"
	error=$(cat ${err})
	mt_fail "[ \"${error}\" = \"failed to open <file>: Permission denied\" ]"
}


## ==========================================================================
## ==========================================================================


write_access()
{
	echo "name = value" > ${workfile}
	chmod 400 ${workfile}

	${sini} set ${workfile} .anything whatever >${out} 2>${err}
	mt_fail "[ ${?} -eq 1 ]"
	stdout="$(cat ${out})"
	mt_fail "[ -z \"${stdout}\" ]"
	error=$(cat ${err})
	mt_fail "[ \"${error}\" = \"failed to open <file>: Permission denied\" ]"
}


## ==========================================================================
## ==========================================================================


dir_write_access()
{
	workdir=$(mktemp -d)
	workfil=$(mktemp -p ${workdir})

	echo "name = value" > ${workfil}
	chmod 500 ${workdir}

	${sini} set ${workfil} .anything whatever >${out} 2>${err}
	mt_fail "[ ${?} -eq 1 ]"
	stdout="$(cat ${out})"
	mt_fail "[ -z \"${stdout}\" ]"
	error=$(cat ${err})
	mt_fail "[ \"${error}\" = \"failed to open temporary data: Permission denied\" ]"

	chmod -R 777 ${workdir}
	rm -r ${workdir}
}


## ==========================================================================
#                                 __                __
#                          _____ / /_ ____ _ _____ / /_
#                         / ___// __// __ `// ___// __/
#                        (__  )/ /_ / /_/ // /   / /_
#                       /____/ \__/ \__,_//_/    \__/
#
## ==========================================================================


tests="space=value
tab=value
space name=space value
tab	name=tab	value
empty-val="

sections="''
section
section space
section-ind-space
section-ind-tab"

IFS=$'\n'
for s in $sections; do
	for t in $tests; do
		name=$(echo "${t}" | cut -f1 -d=)
		val=$(echo "${t}" | cut -f2 -d=)

		for i in $(seq 0 5); do
			object=${s}.${name}${i}
			value=${val}${i}
			if [ "${name}" = "empty-val" ]; then
				value=${val}
			fi
			tname="${object} -> ${value}"

			for m in normal envvar pipein; do
				mt_run_named get_good "get (${m}) ${tname}" "'${object}'" \
					"'${value}'" ${m}
			done
		done
	done
done

set_in="''
.name:value
name = value

name0 = value0
.name1:value1
name0 = value0\nname1 = value1

name0 = value0\nname1 = value1
.name2:value2
name0 = value0\nname1 = value1\nname2 = value2

name0 = value0\n[section]\nsome=val
.name2:value2
name0 = value0\nname2 = value2\n[section]\nsome=val

name0 = value0\n[section]\nsome=val
section.name2:value2
name0 = value0\n[section]\nsome=val\nname2 = value2

name0 = value0\n[section]\nsome=val
new-section.name2:value2
name0 = value0\n[section]\nsome=val\n[new-section]\nname2 = value2

''
section.name:value
[section]\nname = value

[section]\nname = value
section2.name:value
[section]\nname = value\n[section2]\nname = value

[section]\nname = value
section space.name space:value space
[section]\nname = value\n[section space]\nname space = value space

[section]\nname = value\n[section space]\nname space = value space
section space.next name:next value
[section]\nname = value\n[section space]\nname space = value space\nnext name = next value

name0 = value0\nname1 = value1
.name1:value5
name0 = value0\nname1 = value5

name0 = value0\nname1 = value1
.name1:value5 6
name0 = value0\nname1 = value5 6

name0 = value0\nname1 = value5 6\n[s s]\nn = 5\n[s 2]\n\n\nn = 3
s 2.n:4
name0 = value0\nname1 = value5 6\n[s s]\nn = 5\n[s 2]\n\n\nn = 4

name0 = value0\nname1 = value5 6\n\n;comment\n\n[s s]\nn = 5\n[s 2]\nn = 3
s s.p:2
name0 = value0\nname1 = value5 6\n\n;comment\n\n[s s]\nn = 5\np = 2\n[s 2]\nn = 3
"

set -- ${set_in}

i=1
while true; do
	eval tmp=\${${i}}
	if [ -z "${tmp}" ]; then
		break
	fi
	begin=${tmp}
	i=$((i + 1))

	eval tmp=\${${i}}
	object=$(echo "${tmp}" | cut -f1 -d:)
	value=$(echo "${tmp}" | cut -f2 -d:)
	i=$((i + 1))

	eval tmp=\${${i}}
	expect=${tmp}
	i=$((i + 1))

	for m in normal envvar pipein
	do
		mt_run_named set_good "set (${m}) $(( (i - 1) / 3))" \
			"'${begin}'" "'${expect}'" "'${object}'" "'${value}'" ${m}
	done
done

invalids="
name:missing '\''='\'' in key=value, aborting
= value:empty key detected, aborting
   = value:empty key detected, aborting
 = :empty key detected, aborting"

invalids_section="
name = value\n[a]\nname:missing '\''='\'' in key=value, aborting
name = value\n[a]\n= value:empty key detected, aborting
name = value\n[a]\n   = value:empty key detected, aborting
name = value\n[a]\n = :empty key detected, aborting
name = value\n[a\nname = value:unterminated section found, aborting
"

i=0
for inval in ${invalids}; do
	i=$(( i + 1 ))
	file=$(echo "${inval}" | cut -f1 -d:)
	error=$(echo "${inval}" | cut -f2 -d:)
	mt_run_named do_invalid "get_invalid (${i})" "get" "'${file}'" .a "'${error}'"
	# redo error, as it is somehow modified by eval (?)
	error=$(echo "${inval}" | cut -f2 -d:)
	mt_run_named do_invalid "set_invalid (${i})" "set" "'${file}'" .a "'${error}'"
done

for inval in ${invalids_section}; do
	i=$(( i + 1 ))
	file=$(echo "${inval}" | cut -f1 -d:)
	error=$(echo "${inval}" | cut -f2 -d:)
	mt_run_named do_invalid "get_invalid (${i})" "get" "'${file}'" a.a "'${error}'"
	# redo error, as it is somehow modified by eval (?)
	error=$(echo "${inval}" | cut -f2 -d:)
	mt_run_named do_invalid "set_invalid (${i})" "set" "'${file}'" a.a "'${error}'"
done


args="'':no arguments specified
get:file not specified
get .name:invalid object name
get file name:invalid object name
get file section.:invalid object name
get file .:invalid object name
set:file not specified
set file:invalid object name
set file object:invalid object name
set file .:invalid object name
set file section.:invalid object name
set file a.object:value not specified"

for arg in ${args}; do
	a="$(echo "${arg}" | cut -f1 -d:)"
	e="$(echo "${arg}" | cut -f2 -d:)"
	tname="sini ${a}"
	mt_run_named arg_error "${tname}" "'${a}'" "'${e}'"
done

mt_run object_not_found
mt_run object_not_found_in_matchin_section
mt_run object_not_found_in_last_matchin_section
mt_run print_help
mt_run print_version
mt_run line_too_big
mt_run section_line_too_big
mt_run comment_line_too_big
mt_run no_such_file
mt_run read_access
mt_run write_access
mt_run get_with_max_path
mt_run get_with_too_big_path
mt_run get_with_max_name
mt_run get_with_too_big_name
mt_run dir_write_access

mt_return