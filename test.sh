#!/bin/sh
## ==========================================================================
#   Licensed under BSD 2clause license See LICENSE file for more information
#   Author: Michał Łyszczek <michal.lyszczek@bofc.pl>
## ==========================================================================


. ./mtest.sh
sini=./sini
test_ini="./test.ini"
tmp_ini="./tmp.ini"


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
			out="$(${sini} get ${test_ini} "${object}")"
			;;
		envvar)
			out="$(SINI_FILE=${test_ini} ${sini} get "${object}")"
			;;
		pipein)
			out="$(cat ${test_ini} | ${sini} get - "${object}")"
			;;
	esac
	mt_fail "[ ${?} -eq 0 ]"
	mt_fail "[ \"x${out}\" = \"x${value}\" ]"
}


## ==========================================================================
## ==========================================================================


arg_error()
{
	args=${1}
	msg=${2}

	msg+=", check \`sini -h'"
	out=$(mktemp)
	err=$(mktemp)
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

	rm ${out}
	rm ${err}
}


## ==========================================================================
## ==========================================================================


object_not_found()
{
	out=$(mktemp)
	err=$(mktemp)
	${sini} ${test_ini} nonexisting.object >${out} 2>${err}
	mt_fail "[ ${?} -eq 2 ]"

	mt_fail "[ $(stat --format=%s ${out}) -eq 0 ]"
	mt_fail "[ $(stat --format=%s ${err}) -eq 0 ]"

	rm ${out}
	rm ${err}
}


## ==========================================================================
## ==========================================================================


object_not_found_in_matchin_section()
{
	out=$(mktemp)
	err=$(mktemp)
	${sini} ${test_ini} section.does-not-exist >${out} 2>${err}
	mt_fail "[ ${?} -eq 2 ]"

	mt_fail "[ $(stat --format=%s ${out}) -eq 0 ]"
	mt_fail "[ $(stat --format=%s ${err}) -eq 0 ]"

	rm ${out}
	rm ${err}
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

	workfile=$(mktemp)
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

	rm ${workfile}
	rm ${expectfile}
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

name0 = value0\nname1 = value5 6\n[s s]\nn = 5\n[s 2]\nn = 3
s s.n:3
name0 = value0\nname1 = value5 6\n[s s]\nn = 3\n[s 2]\nn = 3

name0 = value0\nname1 = value5 6\n[s s]\nn = 5\n[s 2]\nn = 3
s s.p:2
name0 = value0\nname1 = value5 6\n[s s]\nn = 5\np = 2\n[s 2]\nn = 3
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


mt_return
