set -e
# set -x

[ ${PARSE_ARGS_FLAG:-0} -gt 0 ] && return 0

export PARSE_ARGS_FLAG=1

parse_args_script_path=$(readlink -e "${BASH_SOURCE[0]}")
parse_args_script_dir="${parse_args_script_path%/*}"

parse_args_util_path=$(readlink -e "${parse_args_script_dir}/util.sh")
source "${parse_args_util_path}"

function load_config() {
    debugLog "load_dictionary ${1} ${2}"
    load_dictionary "${1}" "${2}"
}

#-----------------
#
# parse_args
#
# parse function options using declarative configuration from arrays
#
#   all options must precede arguments
#   all options must have values
#   option names must be separated from option values by a space (no --opt=value)
#   both long and short options are supported, -o --long_option
#
# usage:
#   parse_args <parsed_command_ref> <optind_ref> <options_map_ref> <exec_options_map_ref> <argument_list_ref> <subcommands_map_ref> <<descriptions_map_ref> [options...] [arguments...]
#
#   parsed_command: nameref to standard array representing the parsed command,
#                   this is the command being built by the parser
#
#   optind: return value indicates how many arguments were processed
#        0  indicates help request.
#      > 0  number of indexes to shift in the command
#
#   options: associative array where key is the option name including hyphens 
#            and the value is the name of the variable to set
#
#       options=( ["-f"]="myfile" ["--myfile"]="myfile" ["--myparm"]="mycommand_myparm" )
#
#   exec_options: associative array of function references that accept the option value as an argument.
#                 unlike other options, these are executed immediately and hence are order sensitive.
#
#   args: associative array of arguments used to generate help
#
#   subcommands: associative array mapping subcommands to function names
#         functions are not invoked, the arguments are merely translated
#
#   descriptions: associative array where key is the option or argument
#                 and the value is a brief descrption for documentation
#
# sample parse_args command
#
#   command -x opt1 --long_opt opt2 subcommand argA1 argA2
#
# sample configuration in calling function
#
#   local -a mycommand
#   declare -A myoptions=( ["-o"]=option0 \
#                          ["--opt1"]=option1 \
#                          ["--opt2"]=option2 )
#   declare -A myexec_options=( ["-c"]="load_config" )
#                               ["--config"]="load_config" )
#   declare -a myargs=( "arg1" "arg2" )
#   declare -A mysubcommands=( ["sub1"]="subcommand1" ["sub2"]="subcommand2" )
#   declare -A mydescriptions=(
#                               ["-o"]="option0" \
#                               ["--opt1"]="option1" \
#                               ["--opt2"]="option2" \
#                               ["arg1"]="arg1" \
#                               ["sub1"]="subcommand1" \
#                               ["sub2"]="subcommand2"
#                             )
#
#   local myindex
#   local -a mycommand
#   parse_args mycommand myindex myoptions myargs mysubcommands mydescriptions "${@}"
#   shift "${myindex}"
#
#-----------------

function parse_args() {

    debugLog "nargs: $#"
    [ "${#}" -lt 7 ] \
        && printf "usage: parse_args <command_ref> <optind_ref> <options_map_ref> <exec_options_map_ref> <argument_list_ref> <subcommands_map_ref> <descriptions_map_ref> [options...] [arguments...]\n" \
        && return 1

    local -n parsed_command="${1}"
    local -n -r optind="${2}"
    local -n -r options="${3}"
    local -n -r exec_options="${4}"
    local -n -r args="${5}"
    local -n -r subcommands="${6}"
    local -n -r descriptions="${7}"
    shift 7

    # parse options
    local current_index
    local current_option
    local option_value
    local current_exec_option

    optind=0
    while [ "$1" != "" ]; do
        debugLog "parsing [${optind}]: ${1}"
        ((current_index=optind+1))
        param="${1}"
        case "${param}" in
            -h | --help)
                debugLog "[${current_index}]: help"
                parse_args_usage
                optind=0
                break
                ;;
            -* | --*)
                current_option="${options[${param}]}"
                if [ -z "${current_option:+x}" ]; then
                    debugLog "invalid option: [${current_index}] ${param}"
                    return 1
                fi
                debugLog "option: [${current_index}] ${param}: ${current_option}"
                option_value="${2}"
                assign "${current_option}" "${option_value}"
                current_exec_option="${exec_options[${param}]}"
                if [ -n "${current_exec_option}" ]; then
                    "${current_exec_option}" "${option_value}" "${FUNCNAME[1]}"
                fi
                ((optind=optind+2))
                shift 2
                ;;
            *)
                parsed_command+=( "${param}" )
                if [ -n "${subcommands[${param}]}" ]; then
                    parsed_command[0]="${subcommands[${param}]}"
                else
                    parsed_command[0]="${param}"
                fi
                break
                ;;
        esac
    done

    debugLog "FINISHED PARSING"
}


function parse_args_usage() {
    echo "usage: ${FUNCNAME[2]} [options...] [ subcommand ] ${args[@]}"

    echo "arguments"
    for arg in "${args[@]}"; do
        echo "    ${arg}: ${descriptions[${arg}]}"
    done

    echo "options"
    for option in "${!options[@]}"; do
        echo "    ${option}: ${descriptions[${option}]}"
    done

    echo "*** subcommands: ${subcommands[@]} ***"
    for subcommand in "${!subcommands[@]}"; do
        echo "    ${subcommand}: ${subcommands[${subcommand}]}: ${descriptions[${subcommand}]}"
    done

}
