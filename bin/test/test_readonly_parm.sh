

function myfunc() {

    local expected="${1}"
#    local -r myvar="${2:-${myvar:-default_value}}"
    local -r myvar

    echo "expected '${expected}', actual='${myvar}'"

    child
}


function child() {
#    local -r myvar="${1:-${myvar:-child_value}}"
    myvar="override"

    echo "child myvar=${myvar}"
}


myfunc "default_value"
myfunc "some_value" "some_value"

declare myvar=outside

myfunc "outside"

