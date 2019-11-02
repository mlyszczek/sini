#!/bin/sh
## ==========================================================================
#   Licensed under BSD 2clause license See LICENSE file for more information
#   Author: Michał Łyszczek <michal.lyszczek@bofc.pl>
## ==========================================================================


. ./mtest.sh
sini=./sini
test_ini="./test.ini"


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

	out0="$(${sini} get ${test_ini} "${object}")"
	mt_fail "[ ${?} -eq 0 ]"
	out1="$(cat ${test_ini} | ${sini} get - "${object}")"
	mt_fail "[ ${?} -eq 0 ]"
	out2="$(SINI_FILE=${test_ini} ${sini} get "${object}")"
	mt_fail "[ ${?} -eq 0 ]"

	mt_fail "[ \"x${out0}\" = \"x${value}\" ]"
	mt_fail "[ \"x${out1}\" = \"x${value}\" ]"
	mt_fail "[ \"x${out2}\" = \"x${value}\" ]"
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
	${sini} ${args} >${out} 2>${err}
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

			mt_run_named get_good "${tname}" "'${object}'" "'${value}'"
		done
	done
done


args="'':no arguments specified
get:file not specified
get .name:invalid object name
get file name:invalid object name
get file section.:invalid object name
get file .:invalid object name"

for arg in ${args}; do
	a="$(echo "${arg}" | cut -f1 -d:)"
	e="$(echo "${arg}" | cut -f2 -d:)"
	tname="sini ${a}"
	mt_run_named arg_error "${tname}" "'${a}'" "'${e}'"
done

mt_run object_not_found
mt_run object_not_found_in_matchin_section
mt_return
