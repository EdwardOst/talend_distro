set -e
set -x

source talend-packager.sh


talend_packager -m "job_manifest.cfg" -g "com/talend/se/distro/packager" -a "myapp"
