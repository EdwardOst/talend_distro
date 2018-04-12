#!/usr/bin/env bash

[ "${TCF_FLAG:-0}" -gt 0 ] && return 0

export TCF_FLAG=1

set -e
set -u

tcf_script_path=$(readlink -e "${BASH_SOURCE[0]}")
tcf_script_dir="${tcf_script_path%/*}"

source "${tcf_script_dir}/../util/util.sh"
source "${tcf_script_dir}/../util/url.sh"
source "${tcf_script_dir}/../util/file-util.sh"
source "${tcf_script_dir}/../util/array-util.sh"

source "${tcf_script_dir}/package.sh"

#
# contents
#
# help strings
#    tcf_package_help
#    tcf_help
#
# tcf()
# tcf_config()
# tcf_parse_args()
# tcf_package()
# tcf_package_parse_args()
#


define tcf_package_help <<TCF_PACKAGE_HELP
tcf package

    Download all talend job zip files from url's listed in manifest file.
    Merge talend job zip files.
    Rename property and jar files as necessary to minimize namespace collisions.
    Compress the merged files with tgz rather than zip.
    Publish the new app tgz to target nexus.
    TBD: Create a list of all conflicting files.

usage:
    tcf package [-m manifest_file] [-g group_path] [-a app_name] [-v version] [-s source credential] [-t target credential] [-w working directory]

    -m manifest_file: env var TALEND_PACKAGER_JOB_MANIFEST : default "job_manifest.cfg"
    -g target group_path: env var TALEND_PACKAGER_GROUP_PATH : default "com/talend"
    -a target app_name: env var TALEND_PACKAGER_APP_NAME : default "myapp"
    -v target version: env var TALEND_PACKAGER_VERSION : default "0.1.0-SNAPSHOT"
    -s source nexus credential in userid:password format : env var TALEND_PACKAGER_NEXUS_SOURCE_USERID:TALEND_PACKAGER_NEXUS_SOURCE_PASSWORD : default "tadmin:tadmin"
    -t target nexus credential in userid:password format : env var TALEND_PACKAGER_NEXUS_TARGET_USERID:TALEND_PACKAGER_NEXUS_TARGET_PASSWORD : default "tadmin:tadmin"
    -w working directory : env var TALEND_PACKAGER_WORKING_DIR : defaults to creating a temp directory

TCF_PACKAGE_HELP


define tcf_help <<TCF_HELP

Talend Container Factory Help

Provides bash functions to package Talend Jobs as Docker containers.

TCF commands

    * help
    * config
    * package
    * build
    * run
    * deploy

${tcf_package_help}

TCF_HELP


function tcf() {

    local command="${1:-help}"
    command="${command,,}"
    shift 1

    if [ "${command}" == "help" ]; then
        echo "${tcf_help}"
    elif [ "${command}" == "config" ]; then
        tcf_config "${@}"
    elif [ "${command}" == "package" ]; then
        tcf_package "${@}"
    elif [ "${command}" == "build" ]; then
        tcf_build "${@}"
    elif [ "${command}" == "run" ]; then
        tcf_run "${@}"
    elif [ "${command}" == "deploy" ]; then
        tcf_deploy "${@}"
    else
       errorMessage "unknown talend container factory command: ${command}"
    fi

}


function tcf_config() {

    # manifest
    local manifest_path="${manifest_path:-${Manifest_Path:-${MANIFEST_PATH:-${PWD}/manifest.cfg}}}"

    # app configuration
    local app_name="${app_name:-${App_Name:-${APP_NAME:-}"

    # app nexus gav coordinates
    local app_nexus_group="${app_nexus_group:-${App_Nexus_Group:-${APP_NEXUS_GROUP:-com/talend/se/container}}}"
    local app_nexus_artifact="${app_nexus_artifact:-${App_Nexus_Artifact:-${APP_NEXUS_ARTIFACT:-}}}"
    local app_nexus_version="${app_nexus_version:-${App_Nexus_Version:-${APP_NEXUS_VERSION:-0.1.0-SNAPSHOT}}}"

    # docker image config
    local image_user="${image_user:-${Image_User:-${IMAGE_USER:-${USER}}}}"
    local image_name="${image_name:-${Image_Name:-${IMAGE_NAME:-${app_nexus_artifact}}}}"
    local image_version="${image_version:-${Image_Version:-${IMAGE_VERSION:-${app_nexus_version}}}}"

    # docker image internals
    local job_parent_dir="${job_parent_dir:-${Job_Parent_Dir:-${JOB_PARENT_DIR:-/talend}}}"

    tcf "${@}"
}

export tcf_config

# tcf contract
# formation: <param_name>; <arg_index>; <short_arg>; <long_arg>; <required>; <default>; <validation>

declare -A tcf_arg_index=( \
    [nexus_group]="1" \
    [nexus_artifact]="2" \
    [nexus_version]="3" \
    [source_credential]="4" \
    [target_credential]="5" \
    [manifest_path]="6" \
    [work_dir]="7" \
    )

declare -A tcf_short_arg=( \
    [nexus_group]="g" \
    [nexus_artifact]="a" \
    [nexus_version]="v" \
    [source_credential]="s" \
    [target_credential]="t" \
    [manifest_path]="m" \
    [work_dir]="w" \
    )

declare -A tcf_long_arg=( 
    [nexus_group]="group" \
    [nexus_artifact]="artifact" \
    [nexus_version]="version" \
    [source_credential]="source" \
    [target_credential]="target" \
    [manifest_path]="manifest" \
    [work_dir]="work" \
    )

declare -A tcf_required=(
    [nexus_group]="true" \
    [nexus_artifact]="true" \
    [nexus_version]="true" \
    [source_credential]="true" \
    [target_credential]="false" \
    [manifest_path]="false" \
    [work_dir]="false" \
    )

declare -A tcf_default=(
    [manifest_path]="/dev/stdin" \
    [work_dir]="/tmp" \
    )

declare -A tcf_validation=(
    [nexus_group]="valid_nexus_groupid" \
    [nexus_artifact]="valid_nexus_artifactid" \
    [nexus_version]="valid_nexus_version" \
    [source_credential]="valid_nexus_credential" \
    [target_credential]="valid_nexus_credential" \
    [manifest_path]="file_exists" \
    [work_dir]="valid_boolean" \
    )

function tcf_parse_args() {

    local nargs="${#}"
    local current_index=1
    while [ "${current_index}" -le "${nargs}"]; do
        local current_parm="${1}"
        ((current_index=current_index+1))
        shift 1
        debugLog "parsing [${current_index}]: ${current_parm}"
        local current_arg
        if [ "${current_parm:0:2}" == "--" ]; then
            local long_arg="${current_parm:2}"
            current_arg="${tcf_long_arg[${long_arg}]}"
        elif [ "${current_parm:0:1}" == "-" ]; then
            local short_arg="${current_parm:1}"
            if [ "${#short_arg}" -gt 1 ]; then
                errorMessage "error parsing argument ${current_index} '${current_parm}': short option style expecs only a single character option specifier"
                return 1
            fi
        fi
    done

    while getopts ":hm:g:a:v:s:t:w:" opt; do
        case "$opt" in
            h)
                echo "${tcf_help}"
                return 0
                ;;
            m)
                manifest_path="${OPTARG}"
                ;;
            g)
                app_nexus_group="${OPTARG}"
                ;;
            a)
                app_nexus_artifact="${OPTARG}"
                ;;
            v)
                app_nexus_version="${OPTARG}"
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


function tcf_package_parse_args() {

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


function parse_zip_url() {

    local nexus_url="${1}"

    local -A parsed_nexus_url

    parse_url parsed_nexus_url "${nexus_url}"

    local nexus_host="${parsed_nexus_url[host]}"
    local nexus_port="${parsed_nexus_url[port]}"
    local nexus_path="${parsed_nexus_url[path]}"
    local nexus_file="${parsed_nexus_url[file]}"

    local nexus_job_path="${nexus_path#*content/}"
    nexus_job_path="${nexus_job_path%/*}"

    job_file_name="${nexus_file}"
    job_file_root="${nexus_file%.*}"

}


function process_zip() {

    mkdir -p "${working_dir}/${job_file_root}"
    unzip -qq -d "${working_dir}/${job_file_root}" "${working_dir}/${job_file_name}"

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

    local -A parsed_source_url
    parse_url parsed_source_url "${current_url}"

    local job_file_name="${parsed_source_url[file]}"
    local job_file_root="${job_file_name%.*}"

    wget -q --http-user="${nexus_userid}" --http-password="${nexus_password}" --directory-prefix="${working_dir}" "${current_url}" 

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

    # keep permissions using tgz format
    tar -C "${working_dir}" -zcpf "${app_name}.tgz" "${app_name}"

    debugLog "END"
}


function publish_app() {
    debugLog "BEGIN"

    local nexus_target_url="${nexus_target_repo}/${group_path}/${version}/${app_name}-${version}.tgz"

    debugLog "publishing talend app to ${nexus_target_url}"

    curl -u "${nexus_target_userid}:${nexus_target_password}" \
        --upload-file "${app_name}.tgz" \
        "${nexus_target_url}"

    infoLog "Published manifest ${manifest} as app ${app_nexus_group}:${app_nexus_artifactid}:${app_nexus_version} to Nexus ${nexus_host}"

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
    local nexus_source_userid="${TALEND_PACKAGER_NEXUS_SOURCE_USERID:-tadmin}"
    local nexus_source_password="${TALEND_PACKAGER_NEXUS_SOURCE_PASSWORD:-tadmin}"
    local source_credential="${nexus_source_userid}:${nexus_source_password}"
    local nexus_target_repo="${TALEND_PACKAGER_NEXUS_TARGET_REPO:-http://192.168.99.1:8081/nexus/service/local/repositories/snapshots/content}"
    local nexus_target_userid="${TALEND_PACKAGER_NEXUS_TARGET_USERID:-tadmin}"
    local nexus_target_password="${TALEND_PACKAGER_NEXUS_TARGET_PASSWORD:-tadmin}"
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

    publish_app

    debugLog "END"
}
#!/usr/bin/env bash

set -e
set -u

container_run_script_path=$(readlink -e "${BASH_SOURCE[0]}") 
container_run_script_dir="${container_run_script_path%/*}"

source "${container_run_script_dir}/util/util.sh"


function container_run() {

    local image="${1:-${USER}/create_customer}"
    local image_version="${2-0.1}"
    local app_name="${3:-myapp}"
    local job_name="${4:-t1_docker_create_customer_s3}"
    local job_version="${5:-0.1.0-SNAPSHOT}"

    local usage
    define usage << EOF
usage: run [image [image_version [app_name [job_name [job_version]]]]]
defaults: image=${USER}/create_customer
          image_version=0.1
          app_name=myapp
          job_version=0.1.0-SNAPSHOT
EOF

    local [ $# -lt 5 ] && errorMessage usage


    local command
    define command <<EOF
docker run --read-only \\
           -v ~/in:/talend/in:ro \\
           -v ~/out:/talend/out \\
           -v ~/log:/talend/log \\
           -v ~/amc:/talend/amc \\
           --rm -d \\
           ${image}:${image_version} \\
           /talend/${app_name}/${job_name}-${job_version}/${job_name}/${job_name}_run.sh
EOF
    debugInfo -e "${command}"

    docker run --read-only \\
           -v ~/in:/talend/in:ro \\
           -v ~/out:/talend/out \\
           -v ~/log:/talend/log \\
           -v ~/amc:/talend/amc \\
           --rm -d \\
           "${image}:${image_version}" \\
           "/talend/${app_name}/${job_name}-${job_version}/${job_name}/${job_name}_run.sh"

}
