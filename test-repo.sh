set -e
set -x

source util.sh
#source parse-url.sh
source repo.sh

userid=$1
password=$2

#download \
#    "http://www.opensourceetl.net/tis/tpdsbdrt_621/Talend-JobServer-20160704_1411-V6.2.1.zip" \
#    "./downloads" \
#    "${userid}" \
#    "${password}"

#download_manifest "manifest.cfg" \
#    "./downloads" \
#    "${userid}" \
#    "${password}"

download_list "talend-6.2.1.cfg" \
   "/home/ec2-user/eost/talend-distro/6.3.1" \
    "${userid}" \
    "${password}"

checksum downloads
