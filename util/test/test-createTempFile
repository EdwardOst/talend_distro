set -e
set -x

script_path=$(readlink -e "${BASH_SOURCE[0]}")
script_dir="${script_path%/*}"

util_path=$(readlink -e "${script_dir}/../util.sh")
source "${util_path}"

DEBUG_LOG=true

createTempFile
_temp_file=_createTempFile_result
debugVar _temp_file

# exit with error condition
# exit 1

# exit with success condition
exit 0
