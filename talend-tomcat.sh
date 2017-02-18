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

  # default top level parameters
    local _working_dir=$(pwd)

  #download
    local _tomcat_url="${TALEND_TOMCAT_TOMCAT_URL:-http://download.nextag.com/apache/tomcat/tomcat-8/v8.5.11/bin/apache-tomcat-8.5.11.tar.gz}"
    local _tomcat_userid="${TALEND_TOMCAT_TOMCAT_USERID}"
    local _tomcat_password="${TALEND_TOMCAT_TOMCAT_PASSWORD}"

  #publish
    local _nexus_url="${TALEND_TOMCAT_NEXUS_URL:-http://192.168.99.1:8081/nexus/service/local/repositories/snapshots/content}"
    local _nexus_userid="${TALEND_TOMCAT_NEXUS_USERID:-tadmin}"
    local _nexus_password="${TALEND_TOMCAT_NEXUS_PASSWORD:-tadmin}"
    local _nexus_group="${TALEND_TOMCAT_NEXUS_GROUP:-com/talend/tomcat}"

  # internal variables
    local _tomcat_version
    local _tomcat_file


function tomcat_help() {
    cat <<EOF

Download tomcat form url.
Parse tomcat url for version number.
Publish to local nexus.

usage:
    talend_tomcat [-m tomcat_url] [-n nexus_url] [-g nexus_group] [-s source credential] [-t target credential] [-w working_dir] 

    -m tomcat url default: http://download.nextag.com/apache/tomcat/tomcat-8/v8.5.11/bin/apache-tomcat-8.5.11.tar.gz
    -n nexus url default: http://localhost:8081/nexus/service/local/repositories/snapshots/content
    -g group_path default "com/talend/tomcat"
    -s source nexus credential in userid:password format default "tadmin:tadmin"
    -t target nexus credential in userid:password format default "tadmin:tadmin"
    -w working directory default current directory
 
EOF
}


function tomcat_parse_args() {

    local OPTIND=1
    while getopts ":hm:n:g:s:t:w:" opt; do
        case $opt in
            h)
                help
                exit 0
                ;;
            m)
                _tomcat_url="${OPTARG}"
                ;;
            n)
                _nexus_url="${OPTARG}"
                ;;
            g)
                _nexus_group="${OPTARG}"
                ;;
            s)
                local source_credential="${OPTARG}"
                _tomcat_userid="${source_credential%:*}"
                _tomcat_password="${source_credential#*:}"
                ;;
            t)
                local target_credential="${OPTARG}"
                _nexus_userid="${target_credential%:*}"
                _nexus_password="${target_credential#*:}"
                ;;
            w)
                _working_dir="${OPTARG}"
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
