#!/usr/bin/env bash

[ "${TCF_PACKAGE_FLAG:-0}" -gt 0 ] && return 0

export TCF_PACKAGE_FLAG=1

set -e
set -u


tcf_package_script_path=$(readlink -e "${BASH_SOURCE[0]}")
tcf_package_script_dir="${tcf_package_script_path%/*}"

source "${tcf_package_script_dir}/../util/util.sh"
source "${tcf_package_script_dir}/../util/url.sh"
source "${tcf_package_script_dir}/../util/file-util.sh"
source "${tcf_package_script_dir}/../util/array-util.sh"


function help() {
    help_flag=1
    local usage
    define usage <<EOF

Download all talend job zip files from url's listed in manifest file.
Merge all talend job zip files.
Rename property and jar files as necessary to minimize namespace collisions.
TBD: Create a list of all conflicting files.
Compress the merged files with tgz rather than zip.
Publish the new app tgz to target nexus.

usage:
    talend_packager [-m manifest_file] [-n nexus_host] [-g group_path] [-a app_name] [-v version] [-s source credential] [-t target credential] [-w working directory]

    -m manifest_file: env var TALEND_PACKAGER_JOB_MANIFEST : default "job_manifest.cfg"
    -n nexus_host: env var TALEND_PACKAGER_NEXUS_HOST : default "192.168.99.1"
    -g target group_path: env var TALEND_PACKAGER_GROUP_PATH : default "com/talend"
    -a target app_name: env var TALEND_PACKAGER_APP_NAME : default "myapp"
    -v target version: env var TALEND_PACKAGER_VERSION : default "0.1.0-SNAPSHOT"
    -s source nexus credential in userid:password format : env var TALEND_PACKAGER_NEXUS_SOURCE_USERID:TALEND_PACKAGER_NEXUS_SOURCE_PASSWORD : default "tadmin:tadmin"
    -t target nexus credential in userid:password format : env var TALEND_PACKAGER_NEXUS_TARGET_USERID:TALEND_PACKAGER_NEXUS_TARGET_PASSWORD : default "tadmin:tadmin"
    -w working directory : env var TALEND_PACKAGER_WORKING_DIR : defaults to creating a temp directory

EOF
    echo "${usage}"
}


function parse_args() {

    local OPTIND=1
    while getopts ":hm:n:g:a:v:s:t:w:" opt; do
        case "$opt" in
            h)
                help
                return 0
                ;;
            m)
                manifest_file="${OPTARG}"
                ;;
            n)
                nexus_host="${OPTARG}"
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
            s)
                source_credential="${OPTARG}"
                nexus_userid="${source_credential%:*}"
                nexus_password="${source_credential#*:}"
                ;;
            t)
                target_credential="${OPTARG}"
                nexus_target_userid="${target_credential%:*}"
                nexus_target_password="${target_credential#*:}"
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


function process_zip() {

    mkdir -p "${working_dir}/${job_file_root}"

    infoLog "Uzipping '${working_dir}/${job_file_name}' to '${working_dir}/${job_file_root}'"
    unzip -qq -o -d "${working_dir}/${job_file_root}" "${working_dir}/${job_file_name}"

    debugVar job_file_root

    local extglob_save
    extglob_save=$(shopt -p extglob || true )

    shopt -s extglob

    local job_root="${job_file_root/%-+([0-9])\.+([0-9])\.+([0-9])*}"

    eval "${extglob_save}"

    # rename jobInfo.properties
    mv "${working_dir}/${job_file_root}/jobInfo.properties" "${working_dir}/${job_file_root}/jobInfo_${job_root}.properties"
    # collisions are most likely with the routines.jar which has a common name but potentially different content
    mv "${working_dir}/${job_file_root}/lib/routines.jar" "${working_dir}/${job_file_root}/lib/routines_${job_root}.jar"
    # sed command to tweak shell script to use routines_${job_root}.jar
    sed -i "s/routines\.jar/routines_${job_root}\.jar/g" "${working_dir}/${job_file_root}/${job_root}/${job_root}_run.sh"
    # sed command to insert exec at beginning of java invocation
    sed -i "s/^java /exec java /g" "${working_dir}/${job_file_root}/${job_root}/${job_root}_run.sh"
    # exec permission is not set and is not maintianed by zip format, so set it here
    chmod +x "${working_dir}/${job_file_root}/${job_root}/${job_root}_run.sh"
}

function process_job_entry() {
    debugLog "BEGIN"

    local current_url="${1}"

    debugVar "current_url"

    if [ "${current_url:0:1}" == "#" ]; then
        return 0
    else
        infoLog "processing manifest entry: ${current_url}"
    fi

    local -A parsed_source_url
    parse_url parsed_source_url "${current_url}"

    local job_file_name="${parsed_source_url[file]}"
    local job_file_root="${job_file_name%.*}"

    debugLog "attempting to retrieve ${current_url} to ${working_dir}"
    wget -q --http-user="${nexus_userid}" --http-password="${nexus_password}" --directory-prefix="${working_dir}" "${current_url}" && true
    if [ ! $? == 0 ]; then
        errorMessage "error retrieving ${current_url}"
        return 1
    fi

    process_zip "${current_url}"

    # merge zip file contents
    rsync -aibh --stats "${working_dir}/${job_file_root}/" "${working_dir}/target/" > /dev/null

    debugLog "END"
}


function process_manifest() {
    debugLog "BEGIN"

    local manifest_file="${1}"
    local app_name="${2}"

    forline "${manifest_file}" process_job_entry

    mv "${working_dir}/target" "${working_dir}/${app_name}"

    echo "process_manifest: PWD=${PWD}"

    # keep permissions using tgz format
    echo tar -C "${working_dir}" -zcpf "${app_name}.tgz" "${app_name}"
    tar -C "${working_dir}" -zcpf "${app_name}.tgz" "${app_name}"

    echo "tar zip result = ${?}"

    debugLog "END"
}


function publish_app() {
    debugLog "BEGIN"

    local nexus_target_url="${nexus_target_repo}/${group_path}/${version}/${app_name}-${version}.tgz"

    debugLog "publishing talend app to ${nexus_target_url}"

    echo curl -u "${nexus_target_userid}:${nexus_target_password}" \
        -w "\n\nhttp-result=%{http_code}\n" --upload-file "${app_name}.tgz" \
        "${nexus_target_url}"

    curl -u "${nexus_target_userid}:${nexus_target_password}" \
        -w "\n\nhttp-result=%{http_code}\n" --upload-file "${app_name}.tgz" \
        "${nexus_target_url}"

    # shellcheck disable=2154
    infoLog "Published manifest ${manifest} as ${group_path}:${app_name}:${version} to Nexus ${nexus_host}"

    exit 0

    debugLog "END"
}


function talend_packager() {
    debugLog "BEGIN"

    # TODO: allow this to be loaded from a file specified as an option

    # default top level parameters
    local manifest_file="${manifest_file:-${TALEND_PACKAGER_JOB_MANIFEST:-manifest.cfg}}"
    local working_dir="${working_dir:-${TALEND_PACKAGER_WORKING_DIR:-}}"

    [ -z "${working_dir}" ] && create_temp_dir working_dir

    # default nexus source configuration
    local nexus_userid="${TALEND_PACKAGER_NEXUS_USERID:-tadmin}"
    local nexus_password="${TALEND_PACKAGER_NEXUS_PASSWORD:-tadmin}"

    # default nexus target configuration
    local nexus_source_userid="${TALEND_PACKAGER_NEXUS_SOURCE_USERID:-admin}"
    local nexus_source_password="${TALEND_PACKAGER_NEXUS_SOURCE_PASSWORD:-Talend123}"
    local source_credential="${nexus_source_userid}:${nexus_source_password}"
    local nexus_host="${TALEND_PACKAGER_NEXUS_HOST:-192.168.99.1}"
# nexus 2 path
#    local nexus_target_repo="${TALEND_PACKAGER_NEXUS_TARGET_REPO:-http://${nexus_host}:8081/nexus/service/local/repositories/snapshots/content}"
# nexus 3 path
    local nexus_target_repo="${TALEND_PACKAGER_NEXUS_TARGET_REPO:-http://${nexus_host}:8081/repository/snapshots}"
    local nexus_target_userid="${TALEND_PACKAGER_NEXUS_TARGET_USERID:-admin}"
    local nexus_target_password="${TALEND_PACKAGER_NEXUS_TARGET_PASSWORD:-Talend123}"
    local target_credential="${nexus_target_userid}:${nexus_target_password}"
    local group_path="${TALEND_PACKAGER_GROUP_PATH:-com/talend}"
    local app_name="${TALEND_PACKAGER_APP_NAME:-myapp}"
    local version="${TALEND_PACKAGER_VERSION:-0.1.0-SNAPSHOT}"

    # help flag
    local help_flag=0

    parse_args "$@"
    # exit with success value if help was requested
    if [ "${help_flag}" -eq 1 ] ; then
        return 0
    fi

    debugVar manifest_file
    debugVar group_path
    debugVar app_name
    debugVar version
    debugVar source_credential
    debugVar target_credential
    debugVar working_dir

    infoLog "executing: talend_packager -m \"${manifest_file}\" -g \"${group_path}\" -a \"${app_name}\" -v \"${version}\" -s \"${source_credential}\" -t \"${target_credential}\" -w \"${working_dir}\""

    debugLog "adding trap: rm -f \"${app_name}.tgz\""
    trap_add "rm -f ${app_name}.tgz" EXIT
    process_manifest "${manifest_file}" "${app_name}"

    infoVar working_dir
    publish_app

    debugLog "END"
}
