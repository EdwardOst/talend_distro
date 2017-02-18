[ "${TALEND_PACKAGER_FLAG:-0}" -gt 0 ] && return 0

export TALEND_PACKAGER_FLAG=1

script_path=$(readlink -e "${BASH_SOURCE[0]}")
script_dir="${script_path%/*}"

util_path=$(readlink -e "${script_dir}/util.sh")
source "${util_path}"

parse_url_path=$(readlink -e "${script_dir}/parse-url.sh")
source "${parse_url_path}"

function talend_packager() {


# default top level parameters
# TODO: allow this to be loaded from a file specified as an option
# TODO: allow environment defaults

    local manifest_file="job_manifest.cfg"
    local group_path="com/talend"
    local app_name="myapp"
    local version="0.1.0-SNAPSHOT"

# default nexus source configuration
# TODO: allow this to be loaded from a file specified as an option
# TODO: allow environment defaults

    local nexus_userid="tadmin"
    local nexus_password="tadmin"
    local target_dir=~/talend_job

# default nexus target configuration
# TODO: allow this to be loaded from a file specified as an option
# TODO: allow environment defaults

    local nexus_target_protocol="http"
    local nexus_target_host="192.168.99.1"
    local nexus_target_port="8081"
    local nexus_target_repo="nexus/service/local/repositories/snapshots/content"
    local nexus_target_path="com/talend"
    local nexus_target_userid="tadmin"
    local nexus_target_password="tadmin"

# internal instance variables

    local job_extension
    local job_filename
    local job_file_root
    local job_root


function help() {
    cat <<EOF

Download all talend job zip files from url's listed in manifest file.
Merge all talend job zip files.
Rename property and jar files as necessary to minimize namespace collisions.
TBD: Create a list of all conflicting files.
Compress the merged files with tgz rather than zip.
Publish the new app tgz to target nexus.

usage:
    talend_package [-m manifest_file] [-g group_path] [-a app_name] [-v version]

    -m manifest_file default "job_manifest.cfg"
    -g group_path default "com/talend"
    -a app_name default "myapp"
    -v version default "0.1.0-SNAPSHOT"

EOF
}


function parse_args() {

    local OPTIND=1
    while getopts ":hm:g:a:v:" opt; do
        case "$opt" in
            h)
                help
                exit 0
                ;;
            m)
                manifest_file="${OPTARG}"
                ;;
            g)
                group_path="${OPTARG}"
                ;;
            a)
                app_name="${OPTARG}"
                ;;
            v)
                version="${OPTARG}"
                ;;
            ?)
                help >&2
                exit 1
                ;;
        esac
    done
}


function parse_zip_url() {

    local _nexus_url="${1}"

    local -A _parsed_nexus_url

    parse_url _parsed_nexus_url "${_nexus_url}"

    local _nexus_host="${_parsed_nexus_url[host]}"
    local _nexus_port="${_parsed_nexus_url[port]}"
    local _nexus_path="${_parsed_nexus_url[path]}"
    local _nexus_file="${_parsed_nexus_url[file]}"

    local _nexus_job_path="${_nexus_path#*content/}"
    _nexus_job_path="${_nexus_job_path%/*}"

    job_extension="${_nexus_file##*.}"
    job_filename="${_nexus_file}"
    job_file_root="${_nexus_file%.*}"

    local _extglob_save=$(shopt -p extglob)
    shopt -s extglob
    job_root="${job_file_root/%-+([0-9])\.+([0-9])\.+([0-9])*}"
    eval ${_extglob_save}
}


function download_zip() {
    local _nexus_url="${1}"
    wget --http-user="${nexus_userid}" --http-password="${nexus_password}" --directory-prefix="${target_dir}" "${_nexus_url}" 
}


function process_zip() {
    mkdir -p "${target_dir}/${job_file_root}"
    unzip -d "${target_dir}/${job_file_root}" "${target_dir}/${job_filename}"

    # rename jobInfo.properties
    mv "${target_dir}/${job_file_root}/jobInfo.properties" "${target_dir}/${job_file_root}/jobInfo_${job_root}.properties"
    # collisions are most likely with the routines.jar which has a common name but potentially different content
    mv "${target_dir}/${job_file_root}/lib/routines.jar" "${target_dir}/${job_file_root}/lib/routines_${job_root}.jar"
    # sed command to tweak shell script to use routines_${job_root}.jar
    sed -i "s/routines\.jar/routines_${job_root}\.jar/g" "${target_dir}/${job_file_root}/${job_root}/${job_root}_run.sh"
    # sed command to insert exec at beginning of java invocation
    sed -i "s/^java /exec java /g" "${target_dir}/${job_file_root}/${job_root}/${job_root}_run.sh"
}


function merge_zip() {
    rsync -aibvh --stats "${target_dir}/${job_file_root}/" "${target_dir}/target/"
}


function process_job_entry() {
    local _current_url="${1}"

    parse_zip_url "${_current_url}"
    download_zip "${_current_url}"
    process_zip
    merge_zip
}

function process_manifest() {
    local _inputfile="${1}"
    local _app_name="${2}"
    local _current_url

    forline "${_inputfile}" process_job_entry

    mv "${target_dir}/target" "${target_dir}/${_app_name}"
    tar -C "${target_dir}" -zcvf "${_app_name}.tgz" "${_app_name}"
}


function publish_app() {
    local _nexus_target_base="${nexus_target_protocol}://${nexus_target_host}:${nexus_target_port}/${nexus_target_repo}/${group_path}/${version}"
    local _nexus_target_url="${_nexus_target_base}/${app_name}-${version}.tgz"
    curl -v -u "${nexus_target_userid}:${nexus_target_password}" \
        --upload-file "${app_name}.tgz" \
        "${_nexus_target_url}"
}

parse_args "$@"

process_manifest "${manifest_file}" "${app_name}"

publish_app

}

export -f talend_packager
