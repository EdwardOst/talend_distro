#!/usr/bin/env bash

function myfunc() {

    echo "myvar=${myvar}"
}

myvar="hello" myfunc
echo "main: myvar=${myvar}"
