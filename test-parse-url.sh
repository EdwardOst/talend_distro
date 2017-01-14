set -e
# set -x

source util.sh
source parse-url.sh

declare -A url_array

parse_url url_array "http://www.opensourceetl.net/tis/tdf_621/Talend-Installer-Starter-20160704_1411-V6.2.1-installer.zip"

echo "${url_array[url]}"
echo "${url_array[protocol]}"
echo "${url_array[host]}"
echo "${url_array[port]}"
echo "${url_array[path]}"
