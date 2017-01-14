set -e
# set -x

source util.sh
source repo.sh


function talend_tomcat () {


    #download
    local _userid
    local _password
    local _tomcat_url="http://download.nextag.com/apache/tomcat/tomcat-8/v8.5.9/bin/apache-tomcat-8.5.9.tar.gz"
    local _tomcat_protocol
    local _tomcat_port
    local _tomcat_host
    local _tomcat_path
    local _tomcat_version
    local _tomcat_file
    local _target_dir=$(pwd)

    #publish
    local _nexus_repo_url="http://192.168.99.1:8081/nexus/service/local/repositories/snapshots/content"
    local _nexus_userid="tadmin"
    local _nexus_password="tadmin"
    local _nexus_protocol="http"
    local _nexus_host="192.168.99.1"
    local _nexus_port="8081"
    local _nexus_repo="nexus/service/local/repositories/snapshots/content"
    local _nexus_group="com/talend/tomcat"


function tomcat_help() {
    cat <<EOF

Download tomcat form url.
Parse tomcat url for version number.
Publish to local nexus.

usage:
    talend_tomcat [-t tomcat_url] [-d target_dir] [-n nexus_url]

EOF
}


function tomcat_parse_args() {

    local OPTIND=1
    while getopts ":ht:d:n:g:" opt; do
        case $opt in
            h)
                help
                exit 0
                ;;
            t)
                _tomcat_url="${OPTARG}"
                ;;
            d)
                _target_dir="${OPTARG}"
                ;;
            n)
                _nexus_url="${OPTARG}"
                ;;
            g)
                _nexus_group="${OPTARG}"
                ;;
            ?)
                tomcat_help >&2
                exit 1
                ;;
        esac
    done
}


function tomcat_parse_url() {

    # tbd: initialize userid and password if included in url
    # _userid
    # _password

    local _userid_arg
    [ -n "${_userid}" ] && _userid_arg="--http-user=${_userid}"
    local _password_arg
    [ -n "${_password}" ] && _password_arg="--http-password=${_password}"


    _tomcat_url="http://download.nextag.com/apache/tomcat/tomcat-8/v8.5.9/bin/apache-tomcat-8.5.9.tar.gz"

    _tomcat_protocol="${_tomcat_url%%://*}"

    _tomcat_port="${_tomcat_url#*://*:}"
    if [ "${_tomcat_port}" == "${_tomcat_url}" ]; then
        _tomcat_port="80"
    else
        _tomcat_port="${_tomcat_port%%/*}"
    fi

    _tomcat_host="${_tomcat_url#*://}"
    local _tomcat_host_with_port="${_tomcat_host%%:*}"
    local _tomcat_host_no_port="${_tomcat_host%%/*}"
    _tomcat_host="${_tomcat_host_with_port}"
    [ "${#_tomcat_host_no_port}" -lt "${#_tomcat_host_with_port}" ] && _tomcat_host="${_tomcat_host_no_port}"

    _tomcat_path="${_tomcat_url%/*}"
    _tomcat_path="${_tomcat_path#*://*/}"

    _tomcat_version="${_tomcat_path%/*}"
    _tomcat_version="${_tomcat_version##*/v}"

    _tomcat_file="${_tomcat_url##*/}"
}

function tomcat_download() {

    [ -f "${_target_dir}/${_tomcat_file}" ] || \
    wget "${_userid_arg}" \
        "${_password_arg}" \
        -P "${_target_dir}" \
        "${_tomcat_protocol}://${_tomcat_host}:${_tomcat_port}/${_tomcat_path}/${_tomcat_file}"
}


function tomcat_parse_nexus_url() {

    _nexus_protocol="${_nexus_repo_url%%://*}"

    _nexus_port="${_nexus_repo_url#*://*:}"
    if [ "${_nexus_port}" == "${_nexus_repo_url}" ]; then
        _nexus_port="80"
    else
        _nexus_port="${_nexus_port%%/*}"
    fi

    _nexus_host="${_nexus_repo_url#*://}"
    local _nexus_host_with_port="${_nexus_host%%:*}"
    local _nexus_host_no_port="${_nexus_host%%/*}"
    _nexus_host="${_nexus_host_with_port}"
    [ "${#_nexus_host_no_port}" -lt "${#_nexus_host_with_port}" ] && _nexus_host="${_nexus_host_no_port}"

    _nexus_repo="${_nexus_repo_url%/*}"
    _nexus_repo="${_nexus_repo#*://*/}"
    _nexus_repo="${_nexus_repo%%/content/*}/content"
}


function tomcat_publish() {
    local _nexus_target_base="${_nexus_protocol}://${_nexus_host}:${_nexus_port}/${_nexus_repo}"
    local _nexus_target_url="${_nexus_target_base}/${_nexus_group}/${_tomcat_version}/${_tomcat_file}"
    curl -v -u "${_nexus_userid}:${_nexus_password}" \
        --upload-file "${_tomcat_file}" \
        "${_nexus_target_url}"
}


tomcat_parse_args $@

tomcat_parse_url

tomcat_parse_nexus_url

tomcat_download

tomcat_publish
}

export -f talend_tomcat

talend_tomcat $@
