set -e
# set -x

[ ${PARSE_ARGS_FLAG:-0} -gt 0 ] && return 0

export PARSE_ARGS_FLAG=1

parse_args_script_path=$(readlink -e "${BASH_SOURCE[0]}")
parse_args_script_dir="${parse_args_script_path%/*}"

parse_args_util_path=$(readlink -e "${parse_args_script_dir}/util.sh")
source "${parse_args_util_path}"

DEBUG_LOG=true

#-----------------
#
# parse_args
#
# parse arguments to functions to allow options options, arguments, and subcommands.
#
#   all options must precede arguments
#   all options must have values
#   option names must be separated from option values by a space (no --opt=value)
#   both long and short options are supported, -o --long_option
#   long option names must match the local variable names and hence follow bash rules, no hyphens, no periods, just underscores
#
# sample parse_args command
#
#   command -x opt1 -y opt2 \
#      subcommand1 -z1 opt3 \
#          actionA argA1 argA2
#
# parameters
#
#   return code 0 for success, 1 if error processing
#
#   optind return value indicates how many arguments were processed
#        0   indicates help request.
#      > 0   number of indexes to shift in the command
#
#   options:  associative array where key is the option name including hyphens 
#             and the value is the name of the variable to set
#
#       options=( ["-f"]="myfile" ["--myfile"]="myfile" ["--myparm"]="mycommand_myparm" )
#
#   subcommands: associative array where key is the command string
#                and the value is the name of the function to be invoked
#
#       subcommands=( [get]=myfunc_get [operation]=myfunct_operation )
#
#   descriptions: associative array where key is either options or subcommands
#                 and the value is a brief descrption for documentation
#
#   command:  the command being processed consisting of the command name,
#             zero or more options, and zero or more arguements.
#
#-----------------

function parse_args() {

    debugLog "nargs: $#"
    [ "${#}" -lt 5 ] \
        && printf "usage: parse_args <optind_ref> <options_map_ref> <subcommands_map_ref> <descriptions_map_ref> <command [options...] [arguments...]>\n" \
        && return 1

    local -n -r optind="${1}"
    local -n -r options="${2}"
    local -n -r subcommands="${3}"
    local -n -r descriptions="${4}"
    local -r command="${5}"
    shift 5

    # parse options
    local current_index
    local current_option
    local current_subcommand

    optind=1
    while [ "$1" != "" ]; do
        ((current_index=optind+1))
        param="${1}"
        case "${param}" in
            -h | --help)
                debugLog "[${current_index}]: help"
                parse_args_usage
                optind=0
                return 0
                ;;
            --)
                debugLog "[${current_index}] command terminator"
                ((optind=optind+1))
                shift
                break
                ;;
            -* | --*)
                current_option="${options[${param}]}"
                if [ -z "${current_option:+x}" ]; then
                    debugLog "invalid option: [${current_index}] ${param}"
                    return 1
                fi
                debugLog "option: [${current_index}] ${param}: ${current_option}"
                assign "${current_option}" "${2}"
                ((optind=optind+2))
                shift 2
                ;;
            *)
                current_subcommand="${subcommands[${param}]}"
                if [ -z "${current_subcommand:+x}" ]; then
                    debugLog "first argument:[${current_index}] ${param}"
                    "${command}" "${@}"
                    ((optind=optind+"${#}"))
                    shift "${#}"
                    break
                fi
                debugLog "subcommand: [${current_index}] ${param}: ${current_subcommand}"
                ((optind=optind+1))
                shift 1
                debugLog "executing: ${current_subcommand} ${@}"
                debugLog "parse_args" "subindex" "${!options}" \
                                    "${!subcommands}" \
                                    "${!descriptions}" \
                                    "${current_subcommand}" \
                                    "${@}"
                # yuck, we have to call parse args again
                local subindex
                parse_args subindex ${!options} \
                                    ${!subcommands} \
                                    ${!descriptions} \
                                    "${current_subcommand}" \
                                    "${@}"
                ((subindex=subindex-1))
                ((optind=optind+subindex))
                shift "${subindex}"
                break
                ;;
        esac
    done

}


function parse_args_usage() {
    echo "usage: ${command}"

    echo "options"
    for option in "${!options[@]}"; do
        echo "    ${option}: ${descriptions[${option}]}"
    done

    echo "subcommands"
    for subcommand in "${!subcommands[@]}"; do
        echo "    ${option}: ${descriptions[${subcommand}]}"
    done
}
