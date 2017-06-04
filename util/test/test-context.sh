set -e
#set -x

# functions tested
#
# load/export deals with variables
# read/write deals with property files
#
# x load_dictionary - load dictionary into variables
# x load_context - load context into variables
# x export_dictionary - write variables to dictionary
# x export_context - write variables to context
# x read_dictionary - read properties file into dictionary
# x read_context - read properties file into context
# x write_dictionary - write dictionary to properties file
# x write_context - write context to properties file


script_path=$(readlink -e "${BASH_SOURCE[0]}")
script_dir="${script_path%/*}"

util_path=$(readlink -e "${script_dir}/../util.sh")
source "${util_path}"

DEBUG_LOG=true

declare -A my_array

echo -e "\n\nSetup"
echo "my_array keys: ${!my_array[@]}"
echo "my_array values: ${my_array[@]}"

echo "myprefix_var1=${myprefix_var1}"
echo "myprefix_var2=${myprefix_var2}"
echo "myprefix_var3=${myprefix_var3}"

echo -e "\n\ntest_read_dictionary"
read_dictionary "test_read_dictionary.properties" my_array
echo "my_array keys: ${!my_array[@]}"
echo "my_array values: ${my_array[@]}"

echo -e "\n\ntest_write_dictionary"
write_dictionary my_array "test_write_dictionary.properties"
echo "file: test_write_dictionary.properties"
cat "test_write_dictionary.properties"

echo -e "\n\ntest_load_dictionary"
load_dictionary my_array myprefix
echo "myprefix_var1=${myprefix_var1}"
echo "myprefix_var2=${myprefix_var2}"
echo "myprefix_var3=${myprefix_var3}"

echo -e "\n\ntest_export_dictionary"
declare -A another_array
export_dictionary another_array myprefix
echo "another_array keys: ${!another_array[@]}"
echo "another_array values: ${another_array[@]}"



function test_read() {

    local test_read_readVar1
    local test_read_readVar2

    read_context
    echo -e "\nread_context"
    echo "test_read_context keys: ${!test_read_context[@]}"
    echo "test_read_context values: ${test_read_context[@]}"

    load_context
    echo -e "\nload_context"
    echo "test_read_readVar1=${test_read_readVar1}"
    echo "test_read_readVar2=${test_read_readVar2}"
}

echo -e "\n\ntest_read"

declare -A test_read_context
test_read

echo -e "\noutside"
echo "test_read_context keys: ${!test_read_context[@]}"
echo "test_read_context values: ${test_read_context[@]}"



function test_export() {

    local test_export_export1=e1
    local test_export_export2=e2

    export_context
    echo -e "\nexport_context"
    echo "test_export_context keys: ${!test_export_context[@]}"
    echo "test_export_context values: ${test_export_context[@]}"

    write_context
    echo -e "\nwrite_context"
    echo "file: test_export.properties"
    cat "test_export.properties"
}

echo -e "\n\ntest_export"
declare -A test_export_context
test_export

echo "outside"
echo "test_export_context keys: ${!test_export_context[@]}"
echo "test_export_context values: ${test_export_context[@]}"
