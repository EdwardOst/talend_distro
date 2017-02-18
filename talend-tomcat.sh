[ "${TALEND_COMCAT_FLAG:-0}" -gt 0 ] && return 0

export TALEND_TOMCAT_FLAG=1

script_path=$(readlink -e "${BASH_SOURCE[0]}")
script_dir="${script_path%/*}"

util_path=$(readlink -e "${script_dir}/util.sh")
source "${util_path}"

parse_url_path=$(readlink -e "${script_dir}/parse-url.sh")
source "${parse_url_path}"

repo_path=$(readlink -e "${script_dir}/repo.sh")
source "${repo_path}"


function talend_tomcat () {


    #download
    local _tomcat_url="http://download.nextag.com/apache/tomcat/tomcat-8/v8.5.11/bin/apache-tomcat-8.5.11.tar.gz"
    local _tomcat_userid
    local _tomcat_password
    local _tomcat_version
    local _tomcat_file
    local _working_dir=$(pwd)

    #publish
    local _nexus_url="http://192.168.99.1:8081/nexus/service/local/repositories/snapshots/content"
    local _nexus_userid="tadmin"
    local _nexus_password="tadmin"
    local _nexus_group="com/talend/tomcat"


function tomcat_help() {
    cat <<EOF

Download tomcat form url.
Parse tomcat url for version number.
Publish to local nexus.

usage:
    talend_tomcat [-t tomcat_url] [-w working_dir] [-n nexus_url] [-g nexus_group]

EOF
}


function tomcat_parse_args() {

    local OPTIND=1
    while getopts ":ht:w:n:g:u:p:" opt; do
        case $opt in
            h)
                help
                exit 0
                ;;
            t)
                _tomcat_url="${OPTARG}"
                ;;
            w)
                _working_dir="${OPTARG}"
                ;;
            n)
                _nexus_url="${OPTARG}"
                ;;
            g)
                _nexus_group="${OPTARG}"
                ;;
            u)
                _nexus_userid="${OPTARG}"
                ;;
            p)
                _nexus_password="${OPTARG}"
                ;;
            ?)
                tomcat_help >&2
                exit 1
                ;;
        esac
    done
}


function tomcat_parse_url() {

    local _tomcat_userid_arg
    [ -n "${_tomcat_userid}" ] && _tomcat_userid_arg="--http-user=${_tomcat_userid}"
    local _tomcat_password_arg
    [ -n "${_tomcat_password}" ] && _tomcat_password_arg="--http-password=${_tomcat_password}"

    local -A _parsed_tomcat_url
    parse_url _parsed_tomcat_url "${_tomcat_url}"
    local _tomcat_path="${_parsed_tomcat_url[path]}"
    _tomcat_file="${_parsed_tomcat_url[file]}"

    _tomcat_version="${_tomcat_path%/*}"
    _tomcat_version="${_tomcat_version##*/v}"

}

function tomcat_download() {

    [ -f "${_working_dir}/${_tomcat_file}" ] || \
    wget ${_tomcat_userid_arg} ${_tomcat_password_arg} \
        -P "${_working_dir}" \
        "${_tomcat_url}"
}


function tomcat_publish() {
    local _nexus_target_url="${_nexus_url}/${_nexus_group}/${_tomcat_version}/${_tomcat_file}"
    curl -v -u "${_nexus_userid}:${_nexus_password}" \
        --upload-file "${_tomcat_file}" \
        "${_nexus_target_url}"
}


tomcat_parse_args $@

tomcat_parse_url

tomcat_download

tomcat_publish
}

export -f talend_tomcat
