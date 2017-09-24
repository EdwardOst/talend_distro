set -e
# set -x

script_path=$(readlink -e "${BASH_SOURCE[0]}")
script_dir="${script_path%/*}"

util_path=$(readlink -e "${script_dir}/../util.sh")
source "${util_path}"

url_path=$(readlink -e "${script_dir}/../url.sh")
source "${url_path}"

declare -A url_array

parse_url url_array "http://www.opensourceetl.net/tis/tdf_621/Talend-Installer-Starter-20160704_1411-V6.2.1-installer.zip"

echo "${url_array[url]}"
echo "${url_array[protocol]}"
echo "${url_array[host]}"
echo "${url_array[port]}"
echo "${url_array[path]}"
echo "${url_array[file]}"