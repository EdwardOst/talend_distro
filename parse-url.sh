[ "${PARSE_URL_FLAG:-0}" -gt 0 ] && return 0

export PARSE_URL_FLAG=1

script_path=$(readlink -e "${BASH_SOURCE[0]}")
script_dir="${script_path%/*}"

util_path=$(readlink -e "${script_dir}/util.sh")
source "${util_path}"


function parse_url() {

    [ ${#} -lt 2 ] && echo "usage: parse_url <target_url_array> <url>" && exit 1
    local -n _parsed_url=${1}
    local _url=${2}

    local _protocol="${_url%%://*}"

    local _host="${_url#*://}"
    local _port="${_host#*:}"
    local _path="${_host#*/}"
    local _file="${_path##*/}"
    if [ "${_port}" == "${_host}" ]; then
        _host="${_host%%/*}"
        _port="80"
    else
        _host="${_host%%:*}"
        _port="${_port%%/*}"
    fi

    _parsed_url[url]="${_url}"
    _parsed_url[protocol]="${_protocol}"
    _parsed_url[host]="${_host}"
    _parsed_url[port]="${_port}"
    _parsed_url[path]="${_path}"
    _parsed_url[file]="${_file}"
}


export -f parse_url

debugLog "parse-url: loaded"
