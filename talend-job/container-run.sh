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
