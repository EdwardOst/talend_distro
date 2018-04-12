#!/usr/bin/env bash

set -e
set -u

export APP_NAME="talend_sample_container_app"

declare job_id="${1:-}"
declare job_name="${2:-t0_docker_create_customer}"
declare app_name="${3:-talend_sample_container_app}"
declare project_name="${4:-SE_DEMO}"

declare usage="./clean <job_id> <job_name> <app_name> <project_name>"
[ -z "${job_id}" ] && echo "ERROR: missing job_id: ${usage}" && exit 1

declare volume_root="/home/eost/talend_distro/sample_job/volumes"
declare job_instance_root="talend/${project_name}/${app_name}/${job_name}/${job_id}"

sudo rm -rf ${volume_root}/${job_instance_root}
sudo rm -f ${volume_root}/${job_instance_root}/out/*
sudo rm -f ${volume_root}/${job_instance_root}/temp/*
sudo rm -f ${volume_root}/${job_instance_root}/log/*
