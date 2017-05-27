set -e
#set -x

script_path=$(readlink -e "${BASH_SOURCE[0]}")
script_dir="${script_path%/*}"

util_path=$(readlink -e "${script_dir}/../util.sh")
source "${util_path}"

DEBUG_LOG=true

declare -A my_array
load_properties "my.properties" my_array
echo "my_array keys: ${!my_array[@]}"
echo "my_array values: ${my_array[@]}"

echo "Before"
echo "var1=${var1}"
echo "var2=${var2}"
echo "var3=${var3}"

dictionary_to_var my_array

echo "After"
echo "var1=${var1}"
echo "var2=${var2}"
echo "var3=${var3}"
