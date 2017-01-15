#!/bin/bash

# utility functions

[ ${UTIL_FLAG:-0} -gt 0 ] && return 0

export UTIL_FLAG=1

export HELP_DOC_REQUEST=2

# echo message only if DEBUG_LOG variable is set

function debugLog() { 
	if [ -n "${DEBUG_LOG}" ] ; then
		 cat <<< "$@" 1>&2
	fi
}


function debugVar() {
	if [ -n "${DEBUG_LOG}" ] ; then
		cat <<< "${FUNCNAME[*]}: ${1}=${!1}" 1>&2
	fi
}

function debugStack() {
	if [ -n "${DEBUG_LOG}" ] ; then
		[ $# -gt 0 ] && __tag=": $@"
		cat <<< "${FUNCNAME[*]}${__tag}" 1>&2
	fi
}

function yell() { echo "$0: $*" >&2; }

function die() { yell "$*"; exit 111; }

function try() { "$@" || die "cannot $*"; }


#
# set a variable that by convention is the name of the parent function
# prefixed with "_" and appended with "_result" to the 
#
# usage
#	result _myVar
#
function result() { eval _${FUNCNAME[1]}_result='"${!1}"'; }


#
# iterate through an array and apply a function to each element
#
function foreach() {

    [ ${#} -lt 2 ] && echo "usage: foreach <array> <operation>" && exit 1

    local -n _arr=${1}
    local _operation="${2}"
    shift 2

    for item in "${!_arr[@]}"; do
       ${_operation} ${_arr[${item}]} "${@}"
    done
}


function forline() {

    [ ${#} -lt 2 ] && echo "usage: forline <file> <operation>" && exit 1

    local _file="${1}"
    local _operation="${2}"
    shift 2
    local _line

    while IFS='' read -r _line || [[ -n "${_line}" ]]; do
        debugLog "PROCESSING LINE: ${_operation} ${_line} ${@}"
        ${_operation} "${_line}" "${@}"
    done < "${_file}"
}


function createUserOwnedDirectory() {

        if [ "${1}" = "-h" -o "${1}" = "--help" -o $# -lt 1 ] ; then
                cat <<HELPDOC

  createUserOwnedDirectory

  DESCRIPTION

	Create a user owned directory as sudo in some arbitrary location,
	and change the owner and group of the leaf node directory and any
	new intermediate directories created in the process.
	Existing directoryies are not modified.

  CONSTRAINTS
	Assumes access to sudo.

  USAGE:
	createUserOwnedDirectory <fullDirPath> [ <owner> [ <group> ] ]

	parameter: fullDirPath: required
  	parameter: owner: defaults to installUser config or current user if not defined
	parameter: group: defaults to installGroup config or current group if not defined

HELPDOC
                return "${HELP_DOC_REQUEST}"
        fi

	local __fullDirPath="${1}"

	[ -z "${__fullDirPath}" ] && echo "Invalid file path: ${__fullDirPath}" && return 1

	local __parentDir=$(dirname "${__fullDirPath}")
	# if dirname failed then exit
	[ $? -ne 0 ] && echo "Error parsing parent directory: ${__fullDirPath}" && return 1

	debugVar __fullDirPath
	local __owner="${2:-"${installUser:-$(id -un)}"}"; debugVar __owner
	local __group="${3:-"${installUser:-$(id -gn)}"}"; debugVar __group

	[ ! -d "${__parentDir}" ] && createUserOwnedDirectory "${__parentDir}" "${__owner}" "${__group}"

	debugStack "creating ${__owner}:${__group} ${__fullDirPath}"
	sudo mkdir -p ${__fullDirPath}
	sudo chown ${__owner}:${__group} ${__fullDirPath}
}

export -f debugLog
export -f debugVar
export -f debugStack
export -f yell
export -f die
export -f try
export -f createUserOwnedDirectory

export -f foreach
export -f forline

debugLog "util.sh: loaded"
