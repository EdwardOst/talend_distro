# JDK Data Container
FROM anapsix/alpine-java:8u121b13_jdk

MAINTAINER Ed Ost eost@talend.com

ARG nexus_group=com/talend/se/container
ARG nexus_version=0.1.0
ARG app_tgz=talend_sample_container_app-0.1.0-SNAPSHOT.tgz
ARG job_parent_dir=/talend
ARG nexus_host=192.168.99.1

ENV ARG_NEXUS_GROUP=$nexus_group \
    ARG_NEXUS_VERSION=${nexus_version} \
    ARG_APP_TGZ=${app_tgz} \
    ARG_JOB_PARENT_DIR=${job_parent_dir}

ADD "http://${nexus_host}:8081/nexus/service/local/repositories/snapshots/content/${nexus_group}/${nexus_version}/${app_tgz}" "${job_parent_dir}/"
RUN tar xzvpf "${job_parent_dir}/${app_tgz}" -C "${job_parent_dir}" && \
    rm "${job_parent_dir}/${app_tgz}" && \
    mkdir -p /talend/config


ENTRYPOINT [ "/bin/ash" ]
