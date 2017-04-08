# JDK Data Container
FROM anapsix/alpine-java:8u121b13_jdk

MAINTAINER Ed Ost eost@talend.com

ARG job_group=com/talend/se/packager
ARG job_version=0.1.0-SNAPSHOT
ARG job_tgz=myapp-0.1.0-SNAPSHOT.tgz
ARG job_parent_dir=/talend

ADD "http://192.168.99.1:8081/nexus/service/local/repositories/snapshots/content/${job_group}/${job_version}/${job_tgz}" "${job_parent_dir}/"
RUN tar xzvpf "${job_parent_dir}/${job_tgz}" -C "${job_parent_dir}" && \
    rm "${job_parent_dir}/${job_tgz}"

ENTRYPOINT [ "/bin/ash" ]
