[ ${UTIL_FLAG:-0} -gt 0 ] && return 0

export UTIL_FLAG=1

export HELP_DOC_REQUEST=2



function trim() {
    shopt -s extglob
    local -n astring="${1}"
    astring="${astring/#+( )}"
    astring="${astring/%+( )}"
}

#
# define
#
# pretty print define function for reading here documents into a variable
# then use a here string to access it elsewhere
#
# example
# create a template using here document
# backtick allows commands or functions to inject derived content
#
# define my_template <<-EOF
# 	function ${my_func}() {
#	    echo "executing ${my_func}"
#	    `typeset -p my_dictionary`
#	}
#	EOF

define(){ IFS='\n' read -r -d '' "${1}" || true; }




# echo message only if DEBUG_LOG variable is set

function debugLog() { 
    if [ -n "${DEBUG_LOG}" ] ; then
        cat <<< "debug: ${FUNCNAME[*]}: ${@}" 1>&2
    fi
}


# echo message to log

function infoLog() { 
    cat <<< "info: ${FUNCNAME[*]}: ${@}" 1>&2
}


# echo a variable if DEBUG_LOG is set, pass variable name without $ as arg

function debugVar() {
    if [ -n "${DEBUG_LOG}" ] ; then
        cat <<< "debug: ${FUNCNAME[*]}: ${1}=${!1}" 1>&2
    fi
}


# echo a variable to the log, pass variable name without $ as arg

function infoVar() {
    cat <<< "info: ${FUNCNAME[*]}: ${1}=${!1}" 1>&2
}


# print the current call stack to stderr

function debugStack() {
	if [ -n "${DEBUG_LOG}" ] ; then
		[ $# -gt 0 ] && __tag=": $@"
		cat <<< "debug: ${FUNCNAME[*]}${__tag}" 1>&2
	fi
}


# print the current call stack

function infoStack() {
    [ $# -gt 0 ] && __tag=": $@"
    cat <<< "info: ${FUNCNAME[*]}${__tag}" 1>&2
}


# send message to stderr

function yell() { echo "$0: $*" >&2; }


# send message to stderr and exit

function die() { yell "$*"; exit 111; }


# exit if the command is not completed successfully

function try() { "$@" || die "cannot $*"; }


#
# set a variable that by convention is the name of the parent function
# prefixed with "_" and appended with "_result"
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


function assign() {
    [ ${#} -lt 2 ] && echo "usage: assign <var_name> <value>" && exit 1
    local -n var="${1}"
    var="${2}"
    debugVar "${!var}"
}


# read associative array into variables adding an optional prefix
# add/remove a prefix by starting prefix with +/-
#
# usage: load_dictionary <context_array> [prefix [separator]]
#
function load_dictionary() {
    [ ${#} -lt 1 ] && echo "usage: load_dictionary <context_array> [prefix [separator]]" && exit 1

    local -r -n context_array="${1}"
    local prefix="${2}"
    local operator

    if [ -n "${prefix}" ]; then
        local separator="${3:-_}"
        prefix="${prefix}${separator}"
        if [ "${prefix:0,1}" == "-" ]; then
            prefix="${prefix:1}"
            operator="remove_prefix"
        else
            if [ "${prefix:0,1}" == "+" ]; then
                prefix="${prefix:1}"
            fi
            operator="add_prefix"
        fi
    fi

    local property
    for key in "${!context_array[@]}"; do
        property="${key}"
        [ -n "${operator}" ] && "${operator}" "property" "${prefix}"
        assign "${property}" "${context_array[${key}]}"
        debugVar "property"
    done
}


# load context scope into variables 
# context scope does not have a prefix but variables do (in order to avoid namespace collisions)
#
# usage:
#     load_context [context_array]
#
function load_context() {
    local context_array="${1:-${FUNCNAME[1]}_context}"

    load_dictionary "${context_array}" "${FUNCNAME[1]}"
}


# write all variables starting with a prefix to an associative array
# removing the prefix from the key in the process
#
# usage:
#     export_dictionary context_array prefix [separator]]
#
function export_dictionary() {
    [ ${#} -lt 2 ] && echo "usage: export_dictionary <context_array> <prefix> [separator]" && exit 1

    local -n context_array="${1}"
    local prefix="${2}"
    local separator="${3:-_}"

    prefix="${prefix}${separator}"

    local list_params
    define list_params <<-EOF
	local -a var_array=( \${!${prefix}*} )
	EOF
    source /dev/stdin <<< "${list_params}"

    local key
    for var_name in "${var_array[@]}"; do
        key="${var_name}"
        remove_prefix "key" "${prefix}"
        context_array["${key}"]="${!var_name}"
    done
}

# export variables to context
# context name is calling function appended with _context
# prefix is the calling function
#
# usage:
#     export_context
#
function export_context() {
    export_dictionary "${FUNCNAME[1]}_context" "${FUNCNAME[1]}"
}


# read a property file into an associative array, applying an operator to transform the key
#
# usage:
#     parse_property_file <property_key_value_string> <properties_array> <operator> <prefix>
#
function parse_property_file() {
    [ ${#} -lt 4 ] && echo "usage: parse_property_file <property_key_value_string> <properties_array> <operator> <prefix>" && exit 1
    local -r line="${1}"
    local -r -n properties_arr="${2}"
    local -r operator="${3}"
    local prefix="${4}"

    local key="${line%%=*}"
    [ -n "${operator}" ] && "${operator}" "key" "${prefix}"

    local value="${line##*=}"

    debugLog "${!properties_arr}[${key}]=${value}"
    properties_arr["${key}"]="${value}"
}


function remove_prefix() {
    [ ${#} -lt 2 ] && echo "usage: remove_prefix <root> <prefix>" && exit 1
    local -n root="${1}"
    local -r prefix="${2}"
    assign root "${root#${prefix}}"
}


function add_prefix() {
    [ ${#} -lt 2 ] && echo "usage: add_prefix <root> <prefix>" && exit 1
    local -n root="${1}"
    local -r prefix="${2}"
    assign root "${prefix}${root}"
}


# read a property file into an associative array
# optionally add/remove a prefix by starting prefix with +/-
#
# usage:
#     read_dictionary <properties_file> <properties_array> [prefix [separator]]
#
function read_dictionary() {
    [ ${#} -lt 2 ] && echo "usage: read_dictionary <properties_file> <properties_array> [prefix [separator]]" && exit 1
    local -r properties_file="${1}"
    local -r properties_arr="${2}"
    local prefix="${3}"
    local separator="${4:-_}"
    local operator

    mapfile -t < <(grep -v "#" "${properties_file}")

    if [ -n "${prefix}" ]; then
        prefix="${prefix}${separator}"
        if [ "${prefix:0,1}" == "-" ]; then
            prefix="${prefix:1}"
            operator="remove_prefix"
        else
            if [ "${prefix:0,1}" == "+" ]; then
                prefix="${prefix:1}"
            fi
            operator="add_prefix"
        fi
    fi

    foreach MAPFILE parse_property_file "${properties_arr}" "${operator}" "${prefix}"
}


# read property file into context,
# context name is the name of the calling function appended with _context
# prefix each key with the context name
# property file defaults to context name
# by default neither properties nor context keys have prefixes
#
# usage:
#     read_context [property_file]
#
function read_context() {
    local -r properties_file="${1:-${FUNCNAME[1]}.properties}"

    debugLog "read_dictionary ${properties_file} ${FUNCNAME[1]}_context"
    read_dictionary "${properties_file}" "${FUNCNAME[1]}_context"
}


# write associative array to property file
# optionally add/remove a prefix by starting prefix with +/-
#
# usage
#     write_dictionary <properties_array> <properties_file> [prefix [separator]]
#
function write_dictionary() {
    [ ${#} -lt 2 ] && echo "usage: write_dictionary <properties_array> <properties_file> [prefix [separator]]" && exit 1
    local -r -n properties_arr="${1}"
    local -r properties_file="${2}"
    local prefix="${3}"
    local separator="${4:-_}"
    local operator

    if [ -n "${prefix}" ]; then
        prefix="${prefix}${separator}"
        if [ "${prefix:0,1}" == "-" ]; then
            prefix="${prefix:1}"
            operator="remove_prefix"
        else
            if [ "${prefix:0,1}" == "+" ]; then
                prefix="${prefix:1}"
            fi
            operator="add_prefix"
        fi
    fi

    local property
    for key in "${!properties_arr[@]}"; do
        property="${key}"
        [ -n "${operator}" ] && "${operator}" "property" "${prefix}"
        echo "${property}=${properties_arr[${key}]}"
    done > "${properties_file}"
}

# write context to property file
# context name is the name of the calling function
# strip the prefix from each key before writing
# the prefix is the context name
# property file defaults to context name
# by default neither properties nor context keys have a prefix
#
# usage:
#     write_context [properties_array [properties_file]]
#
function write_context() {
    local properties_array="${1:-${FUNCNAME[1]}_context}"
    local -r properties_file="${2:-${FUNCNAME[1]}.properties}"

    write_dictionary "${properties_array}" "${properties_file}"
}


function createUserOwnedDirectory() {

    if [ "${1}" = "-h" -o "${1}" = "--help" -o $# -lt 1 ] ; then
        cat <<-HELPDOC

	createUserOwnedDirectory

	  DESCRIPTION

	    Create a user owned directory as sudo in some arbitrary location,
	    and change the owner and group of the leaf node directory and any
	    new intermediate directories created in the process.
	    existing directoryies are not modified.

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


trap_add() {
    if [ "${1}" = "-h" -o "${1}" = "--help" -o $# -lt 2 ] ; then
        cat <<-HELPDOC
	  DESCRIPTION

	  USAGE
	    trap_add <handler> <signal>

	    parameter: handler: a command or usually a function used as a signal handler
            parameter: signal: one or more trappable SIGNALS to which the handler will be attached
	HELPDOC
        return ${HELP_DOC_REQUEST} 
    fi

    local _trap_command=$1
    shift 1
    local _trap_signal
    for _trap_signal in "$@"; do
        debugVar _trap_signal

        # Get the currently defined traps
        debugLog $(trap -p "${_trap_signal}" | awk -F"'" '{print $2}')
        local _existing_trap=$(trap -p "${_trap_signal}" | awk -F"'" '{print $2}')

        # Remove single apostrophe formatting wrapper
        _existing_trap=${_existing_trap#\'}
        _existing_trap=${_existing_trap%\'}
        debugVar _existing_trap

        # Append new trap to old trap
        [ -n "${_existing_trap}" ] && _existing_trap="${_existing_trap};"
        local _new_trap="${_existing_trap}${_trap_command}"
        debugVar _new_trap

        # Assign the composed trap
         trap "${_new_trap}" "${_trap_signal}"
    done
}

# set the trace attribute for the above function.  this is
# required to modify DEBUG or RETURN traps because functions don't
# inherit them unless the trace attribute is set
declare -f -t trap_add

createTempFile() {
    local _tempFile=$(mktemp)
    trap_add "rm -f ${_tempFile}" EXIT
    result _tempFile
}

createTempDir() {
    local _tempDir=$(mktemp -d)
    trap_add "rm -rf ${_tempDir}" EXIT
    result _tempDir
}


# load/export deals with variables
# read/write deals with property files

export -f trim
export -f define
export -f debugLog
export -f debugVar
export -f infoLog
export -f infoVar
export -f debugStack
export -f infoStack
export -f yell
export -f die
export -f try
export -f result
export -f foreach
export -f forline
export -f assign
export -f load_dictionary
export -f load_context
export -f export_dictionary
export -f export_context
export -f parse_property_file
export -f remove_prefix
export -f add_prefix
export -f read_dictionary
export -f read_context
export -f write_dictionary
export -f write_context
export -f createUserOwnedDirectory
export -f trap_add
export -f createTempFile
export -f createTempDir

debugLog "util.sh: loaded"
