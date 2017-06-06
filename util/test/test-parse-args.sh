set -e
# set -x

script_path=$(readlink -e "${BASH_SOURCE[0]}")
script_dir="${script_path%/*}"

util_path=$(readlink -e "${script_dir}/../util.sh")
source "${util_path}"

parse_args_path=$(readlink -e "${script_dir}/../parse_args.sh")
source "${parse_args_path}"


function my_load_config() {
    debugLog "load_dictionary ${1}"
    load_dictionary "${1}"
}


function myfunc() {

local -a mycommand
declare -A myoptions=( ["-o"]=option0 ["--opt1"]=option1 ["--opt2"]=option2 ["-c"]=load_config ["--config"]=load_config )
declare -A myexec_options=( ["-c"]="my_load_config" \
                            ["--c"]="my_load_config" )
declare -a myargs=( "arg1" "arg2" )
declare -A mysubcommands=( ["sub1"]="subcommand1" ["sub2"]="subcommand2" )
declare -A mydescriptions=(
                            ["-o"]="option0" \
                            ["--opt1"]="option1" \
                            ["--opt2"]="option2" \
                            ["arg1"]="arg1" \
                            ["sub1"]="subcommand1" \
                            ["sub2"]="subcommand2"
                          )

local myindex
local option0=default0
local option1=default1
local option2=default2
local arg1
local arg2


parse_args mycommand myindex myoptions myexec_options myargs mysubcommands mydescriptions "${@}"

echo "myindex=${myindex}"
echo "old args: ${@}"
shift "${myindex}"
echo "new args: ${@}"
echo "mycommand: ${mycommand[@]}"

echo "option0=${option0}"
echo "option1=${option1}"
echo "option2=${option2}"
}

declare -A test_config=( ["option0"]="test0" ["option1"]="test1" ["option2"]="test2" )

#myfunc
#myfunc -h
#myfunc -o value0
#myfunc --opt1 value1
#myfunc -o value1 --opt2 value2
#myfunc -o value1 --opt2 value2 arg1
#myfunc -o value1 --opt2 value2 sub1 arg1
#myfunc -c test_config --opt2 value2 sub1 arg1
myfunc -c test_config --opt2 value2 sub1 arg1
myfunc -o value0 -c test_config --opt2 value2 sub1 arg1
