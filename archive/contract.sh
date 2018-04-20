#!/usr/bin/env bash

set -u

[ "${CONTRACT_FLAG:-0}" -gt 0 ] && return 0

export CONTRACT_FLAG=1

contract_script_path=$(readlink -e "${BASH_SOURCE[0]}")
contract_script_dir="${contract_script_path%/*}"

source "${contract_script_dir}/util.sh"


define contract_doc_help <<CONTRACT_DOC_HELP

Shell Contract

The shell contract module allows specification of function signatures.
The contract can be directly scripted as a set of declarative arrays which are then used to parse a function invocation.
The contract handles flexible parsing of named and positinoal arguments using both short and long form options.
The contract can be serialized to a file.

contract format:
<param_name>; <param_index>; <short_option>; <long_option>; <required>; <default>; <validation>

The contract follows the convention that the arguments being parsed are overriding default values which may have
already been set in the parent scope.  

In order to preserve read-only semantics consistent with bash scoping rules, the contract must wrap the target function.
Otherwise, if the target function invoked the contract, read-only parameters would not be supported because they would
need to be declared in the target function because of scoping rules, but they could not be set in the parsing function.

So the contract declares arguments locally using the following precedence conventions.

    local -r my_parm="\${<argIndex>:-\${my_parm:-\${MY_PARM:-my_default}}}"

The actual target function will be invoked by the contract wrapper, so the parameters will have the scope of the
contract wrapper rather than the function itself.


CONTRACT_DOC_HELP

