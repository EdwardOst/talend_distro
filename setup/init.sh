#!/usr/bin/env bash

set -e
set -u

script_path=$(readlink -e "${BASH_SOURCE[0]}")
script_dir="${script_path%/*}"

#source ../util/util.sh
source "${script_dir}/../util/util.sh"

function init_global() {

    local _talend_docker_home="${1:-}"
    local -r talend_docker_home_dir="${2:-${TALEND_DOCKER_HOME}}"

    required _talend_docker_home talend_docker_home_dir

    local global_dir
    global_dir=$(readlink -m "${talend_docker_home_dir}")
    assign "${_talend_docker_home}" "${global_dir}"

    infoLog "Setting up talend-docker directory '${global_dir}'"
    mkdir -p "${global_dir}"

    infoLog "Create global config directory '${global_dir}/config'"
    mkdir -p "${global_dir}/config"
    cp "${script_dir}/template/global.cfg" "${global_dir}/config"
}


function init_project() {
    local _talend_docker_project_dir="${1:-}"
    local -r global_dir="${2:-}"
    local -r project_name="${3:-${TALEND_DOCKER_PROJECT_NAME}}"

    required _talend_docker_project_dir global_dir project_name

    local -r project_dir="${global_dir}/${project_name}"
    assign "${_talend_docker_project_dir}" "${project_dir}"

    infoLog "Creating project config directory '${project_dir}/config'"
    mkdir -p "${project_dir}/config"
    cp "${script_dir}/template/project.cfg" "${project_dir}/config"
}


function init_app() {
    local _talend_docker_app_dir="${1:-}"
    local -r global_dir="${2:-}"
    local -r project_dir="${3:-}"
    local -r app_name="${4:-${TALEND_DOCKER_APP_NAME}}"

    required _talend_docker_app_dir global_dir project_dir app_name

    local -r app_dir="${project_dir}/${app_name}"
    assign "${_talend_docker_app_dir}" "${app_dir}"

    # create shared input directory
    mkdir -p "${app_dir}"
    cp -r "${script_dir}/template/data" "${app_dir}"
    infoLog "Application input copied to: '${app_dir}/data'"
}


function init_job() {
    local _talend_docker_job_dir="${1:-}"
    local -r global_dir="${2:-}"
    local -r project_dir="${3:-}"
    local -r app_dir="${4:-}"
    local -r job_name="${5:-${TALEND_DOCKER_JOB_NAME}}"

    required _talend_docker_job_dir global_dir project_dir app_dir job_name

    local -r job_dir="${app_dir}/${job_name}"
    assign "${_talend_docker_job_dir}" "${job_dir}"

    # create job config directory
    mkdir -p "${job_dir}/config"

# default job_config sets the shared input directory
declare job_config_content
define job_config_content <<EOF
my_property="some_value"
EOF
    local -r job_config_file_path="${job_dir}/config/job.cfg"
    printf "%s" "${job_config_content}" > "${job_config_file_path}"
    infoLog "Job configuration written to: '${job_config_file_path}'"

}
