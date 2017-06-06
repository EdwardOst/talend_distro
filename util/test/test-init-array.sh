set -e
#set -x

#DEBUG_LOG=true

#script_path=$(readlink -e "${BASH_SOURCE[0]}")
#script_dir="${script_path%/*}"

#util_path=$(readlink -e "${script_dir}/../util.sh")
#source "${util_path}"

function init_array() {
    local -n command="${1}"
    declare -i index=0

    shift 1
    for item in "${@}"; do
        command["${index}"]="${item}"
        ((index+=1))
    done
}


declare -a mycommand=
declare -a oldcommand=( a b c )
init_array "mycommand" "${oldcommand[@]}"

echo "mycommand=${mycommand[@]}"
