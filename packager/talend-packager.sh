[ "${TALEND_PACKAGER_FLAG:-0}" -gt 0 ] && return 0

export TALEND_PACKAGER_FLAG=1

talend_packager_script_path=$(readlink -e "${BASH_SOURCE[0]}")
talend_packager_script_dir="${talend_packager_script_path%/*}"

talend_packager_util_path=$(readlink -e "${talend_packager_script_dir}/util/util.sh")
source "${talend_packager_util_path}"

talend_packager_url_path=$(readlink -e "${talend_packager_script_dir}/util/url.sh")
source "${talend_packager_url_path}"

function talend_packager() {

# TODO: allow this to be loaded from a file specified as an option

  # default top level parameters
    local _manifest_file="${TALEND_PACKAGER_JOB_MANIFEST:-job_manifest.cfg}"
    local _working_dir
    if [ -n "${TALEND_PACKAGER_WORKING_DIR}" ] ; then
        _working_dir="${TALEND_PACKAGER_WORKING_DIR}"
    else
        createTempDir
        _working_dir="${_createTempDir_result}"
    fi

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
    talend_package [-m manifest_file] [-g group_path] [-a app_name] [-v version] [-s source credential] [-t target credential] [-w working directory]

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
                _manifest_file="${OPTARG}"
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
                _working_dir="${OPTARG}"
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


function download_zip() {
    local _nexus_url="${1}"
    wget -q --http-user="${_nexus_userid}" --http-password="${_nexus_password}" --directory-prefix="${_working_dir}" "${_nexus_url}" 
}


function process_zip() {

    local _current_url="${1}"

    local -A _parsed_source_url
    parse_url _parsed_source_url "${_current_url}"

    local _job_file_name="${_parsed_source_url[file]}"
    local _job_file_root="${_job_file_name%.*}"

    mkdir -p "${_working_dir}/${_job_file_root}"
    unzip -qq -d "${_working_dir}/${_job_file_root}" "${_working_dir}/${_job_file_name}"

    local _extglob_save=$(shopt -p extglob)
    shopt -s extglob
    local job_root="${_job_file_root/%-+([0-9])\.+([0-9])\.+([0-9])*}"
    eval ${_extglob_save}

    # rename jobInfo.properties
    mv "${_working_dir}/${_job_file_root}/jobInfo.properties" "${_working_dir}/${_job_file_root}/jobInfo_${job_root}.properties"
    # collisions are most likely with the routines.jar which has a common name but potentially different content
    mv "${_working_dir}/${_job_file_root}/lib/routines.jar" "${_working_dir}/${_job_file_root}/lib/routines_${job_root}.jar"
    # sed command to tweak shell script to use routines_${job_root}.jar
    sed -i "s/routines\.jar/routines_${job_root}\.jar/g" "${_working_dir}/${_job_file_root}/${job_root}/${job_root}_run.sh"
    # sed command to insert exec at beginning of java invocation
    sed -i "s/^java /exec java /g" "${_working_dir}/${_job_file_root}/${job_root}/${job_root}_run.sh"
    # exec permission is not set and is not maintianed by zip format, so set it here
    chmod +x "${_working_dir}/${_job_file_root}/${job_root}/${job_root}_run.sh"
}


function merge_zip() {
    rsync -aibh --stats "${_working_dir}/${_job_file_root}/" "${_working_dir}/target/" > /dev/null
}


function process_job_entry() {
    local _current_url="${1}"

    download_zip "${_current_url}"
    process_zip "${_current_url}"
    merge_zip
}

function process_manifest() {
    local _inputfile="${1}"
    local _app_name="${2}"
    local _current_url

    forline "${_inputfile}" process_job_entry

    mv "${_working_dir}/target" "${_working_dir}/${_app_name}"
    # keep permissions using tgz format
    tar -C "${_working_dir}" -zcpf "${_app_name}.tgz" "${_app_name}"
}


function publish_app() {
    local nexus_target_url="${_nexus_target_repo}/${_group_path}/${_version}/${_app_name}-${_version}.tgz"
    curl -u "${_nexus_target_userid}:${_nexus_target_password}" \
        --upload-file "${_app_name}.tgz" \
        "${nexus_target_url}"
}

parse_args "$@"
# exit with success value if help was requested
if [ ${_help_flag} -eq 1 ] ; then
    return 0
fi

echo "executing: talend_package -m \"${_manifest_file}\" -g \"${_group_path}\" -a \"${_app_name}\" -v \"${_version}\" -s \"${_source_credential}\" -t \"${_target_credential}\" -w \"${_working_dir}\""


trap_add "rm -f \"${_app_name}.tgz\"" EXIT
process_manifest "${_manifest_file}" "${_app_name}"

publish_app

}

export -f talend_packager
