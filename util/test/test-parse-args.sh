set -e
# set -x

script_path=$(readlink -e "${BASH_SOURCE[0]}")
script_dir="${script_path%/*}"

util_path=$(readlink -e "${script_dir}/../util.sh")
source "${util_path}"

parse_args_path=$(readlink -e "${script_dir}/../parse_args.sh")
source "${parse_args_path}"

myindex=0
declare -A myoptions=( ["-o"]=option1 ["--opt1"]=option1 ["--opt2"]=option2 )
declare -A mysubcommands=( ["cmd1"]=mycommand1 ["cmd2"]=mycommand2 )
declare -A mydescriptions=( ["-g"]="myget shortoption" \
                            ["--get"]="myget long option" \
                            ["cmd1"]="my subcommand 1" \
                            ["cmd2"]="my subcommand 2" )

#command_array=( "badcommand" )
#command_array=( "cmd1" )

function mycommand1() {
    myarg="${1}"
    echo "mycommand1: option1=${option1} option2=${option2} myarg=${myarg}"
}

#command_array=( "mycommand" "-o" "value1" "cmd1" "--opt2" "value2" "arg1" )
command_array=( "mycommand" "-h" )
parse_args myindex myoptions mysubcommands mydescriptions "${command_array[@]}"
echo "command_array=${command_array[@]}"
echo "myindex=${myindex}"
newarray=( "${command_array[@]:${myindex}}" )
echo "newarray=" "${newarray[@]}"

