#!/usr/bin/env bash

[ "${TALEND_PACKAGER_FLAG:-0}" -gt 0 ] && return 0

export TALEND_PACKAGER_FLAG=1

set -e
set -u


talend_packager_script_path=$(readlink -e "${BASH_SOURCE[0]}")
talend_packager_script_dir="${talend_packager_script_path%/*}"

talend_packager_util_path=$(readlink -e "${talend_packager_script_dir}/util/util.sh")
source "${talend_packager_util_path}"

talend_packager_url_path=$(readlink -e "${talend_packager_script_dir}/util/url.sh")
source "${talend_packager_url_path}"

talend_packager_file_util_path=$(readlink -e "${talend_packager_script_dir}/util/file-util.sh")
source "${talend_packager_file_util_path}"

talend_packager_array_util_path=$(readlink -e "${talend_packager_script_dir}/util/array-util.sh")
source "${talend_packager_array_util_path}"



function help() {
    _help_flag=1
    cat <<EOF

Download all talend job zip files from url's listed in manifest file.
Merge all talend job zip files.
Rename property and jar files as necessary to minimize namespace collisions.
TBD: Create a list of all conflicting files.
Compress the merged files with tgz rather than zip.
Publish the new app tgz to target nexus.

usage:
    talend_packager [-m manifest_file] [-g group_path] [-a app_name] [-v version] [-s source credential] [-t target credential] [-w working directory]

    -m manifest_file: env var TALEND_PACKAGER_JOB_MANIFEST : default "job_manifest.cfg"
    -g target group_path: env var TALEND_PACKAGER_GROUP_PATH : default "com/talend"
    -a target app_name: env var TALEND_PACKAGER_APP_NAME : default "myapp"
    -v target version: env var TALEND_PACKAGER_VERSION : default "0.1.0-SNAPSHOT"
    -s source nexus credential in userid:password format : env var TALEND_PACKAGER_NEXUS_SOURCE_USERID:TALEND_PACKAGER_NEXUS_SOURCE_PASSWORD : default "tadmin:tadmin"
    -t target nexus credential in userid:password format : env var TALEND_PACKAGER_NEXUS_TARGET_USERID:TALEND_PACKAGER_NEXUS_TARGET_PASSWORD : default "tadmin:tadmin"
    -w working directory : env var TALEND_PACKAGER_WORKING_DIR : defaults to creating a temp directory

EOF
}


function parse_args() {

    local OPTIND=1
    while getopts ":hm:g:a:v:s:t:w:" opt; do
        case "$opt" in
            h)
                help
                return 0
                ;;
            m)
                manifest_file="${OPTARG}"
                ;;
            g)
                _group_path="${OPTARG}"
                ;;
            a)
                _app_name="${OPTARG}"
                ;;
            v)
                _version="${OPTARG}"
                ;;
            s)
                _source_credential="${OPTARG}"
                _nexus_userid="${_source_credential%:*}"
                _nexus_password="${_source_credential#*:}"
                ;;
            t)
                _target_credential="${OPTARG}"
                _nexus_target_userid="${_target_credential%:*}"
                _nexus_target_password="${_target_credential#*:}"
                ;;
            w)
                working_dir="${OPTARG}"
                ;;
            ?)
                help >&2
                return 2
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

    _job_file_name="${_nexus_file}"
    _job_file_root="${_nexus_file%.*}"

}


function process_zip() {

    mkdir -p "${working_dir}/${_job_file_root}"
    unzip -qq -d "${working_dir}/${_job_file_root}" "${working_dir}/${_job_file_name}"

    debugVar _job_file_root

    local _extglob_save
    _extglob_save=$(shopt -p extglob || true )

    shopt -s extglob

    local job_root="${_job_file_root/%-+([0-9])\.+([0-9])\.+([0-9])*}"

    eval "${_extglob_save}"

    # rename jobInfo.properties
    mv "${working_dir}/${_job_file_root}/jobInfo.properties" "${working_dir}/${_job_file_root}/jobInfo_${job_root}.properties"
    # collisions are most likely with the routines.jar which has a common name but potentially different content
    mv "${working_dir}/${_job_file_root}/lib/routines.jar" "${working_dir}/${_job_file_root}/lib/routines_${job_root}.jar"
    # sed command to tweak shell script to use routines_${job_root}.jar
    sed -i "s/routines\.jar/routines_${job_root}\.jar/g" "${working_dir}/${_job_file_root}/${job_root}/${job_root}_run.sh"
    # sed command to insert exec at beginning of java invocation
    sed -i "s/^java /exec java /g" "${working_dir}/${_job_file_root}/${job_root}/${job_root}_run.sh"
    # exec permission is not set and is not maintianed by zip format, so set it here
    chmod +x "${working_dir}/${_job_file_root}/${job_root}/${job_root}_run.sh"
}

function process_job_entry() {
    local current_url="${1}"

    debugLog "process_job_entry: ${current_url}"

    local -A _parsed_source_url
    parse_url _parsed_source_url "${current_url}"

    local _job_file_name="${_parsed_source_url[file]}"
    local _job_file_root="${_job_file_name%.*}"

    # download zip
    debugLog "download_zip ${current_url}"
    local _nexus_url="${current_url}"
    wget -q --http-user="${_nexus_userid}" --http-password="${_nexus_password}" --directory-prefix="${working_dir}" "${current_url}" 

    debugLog "process_zip: ${current_url}"
    process_zip "${current_url}"

    # merge zip file contents
    rsync -aibh --stats "${working_dir}/${_job_file_root}/" "${working_dir}/target/" > /dev/null
}


function process_manifest() {
    local manifest_file="${1}"
    local app_name="${2}"

    forline "${manifest_file}" process_job_entry

    mv "${working_dir}/target" "${working_dir}/${app_name}"

    # keep permissions using tgz format
    tar -C "${working_dir}" -zcpf "${app_name}.tgz" "${app_name}"
}


function publish_app() {
    local nexus_target_url="${_nexus_target_repo}/${_group_path}/${_version}/${_app_name}-${_version}.tgz"

    debugLog "publishing talend app to ${nexus_target_url}"

    curl -u "${_nexus_target_userid}:${_nexus_target_password}" \
        --upload-file "${_app_name}.tgz" \
        "${nexus_target_url}"
}


function talend_packager() {

    # TODO: allow this to be loaded from a file specified as an option

    # default top level parameters
    local manifest_file="${manifest_file:-${TALEND_PACKAGER_JOB_MANIFEST:-manifest.cfg}}"
    local working_dir="${working_dir:-${TALEND_PACKAGER_WORKING_DIR:-}}"

    [ -z "${working_dir}" ] && create_temp_dir working_dir

    # default nexus source configuration
    local _nexus_userid="${TALEND_PACKAGER_NEXUS_USERID:-tadmin}"
    local _nexus_password="${TALEND_PACKAGER_NEXUS_PASSWORD:-tadmin}"

    # default nexus target configuration
    local _nexus_source_userid="${TALEND_PACKAGER_NEXUS_SOURCE_USERID:-tadmin}"
    local _nexus_source_password="${TALEND_PACKAGER_NEXUS_SOURCE_PASSWORD:-tadmin}"
    local _source_credential="${_nexus_source_userid}:${_nexus_source_password}"
    local _nexus_target_repo="${TALEND_PACKAGER_NEXUS_TARGET_REPO:-http://192.168.99.1:8081/nexus/service/local/repositories/snapshots/content}"
    local _nexus_target_userid="${TALEND_PACKAGER_NEXUS_TARGET_USERID:-tadmin}"
    local _nexus_target_password="${TALEND_PACKAGER_NEXUS_TARGET_PASSWORD:-tadmin}"
    local _target_credential="${_nexus_target_userid}:${_nexus_target_password}"
    local _group_path="${TALEND_PACKAGER_GROUP_PATH:-com/talend}"
    local _app_name="${TALEND_PACKAGER_APP_NAME:-myapp}"
    local _version="${TALEND_PACKAGER_VERSION:-0.1.0-SNAPSHOT}"

    # help flag
    local _help_flag=0

    parse_args "$@"
    # exit with success value if help was requested
    if [ "${_help_flag}" -eq 1 ] ; then
        return 0
    fi

    debugLog "executing: talend_package -m \"${manifest_file}\" -g \"${_group_path}\" -a \"${_app_name}\" -v \"${_version}\" -s \"${_source_credential}\" -t \"${_target_credential}\" -w \"${working_dir}\""

    debugLog "adding trap: rm -f \"${_app_name}.tgz\""
    trap_add "rm -f ${_app_name}.tgz" EXIT
    process_manifest "${manifest_file}" "${_app_name}"

    publish_app

    debugLog "finished talend_packager"
}
