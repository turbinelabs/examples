# envcheck.sh should be sourced in scripts that want to check for the
# presence of required environment variables or to rewrite environment
# variables with a different prefix.

# Default file for messages. Preset value wins, for ease of testing.
[[ -n "${_ec_output}" ]] || _ec_output=/dev/stderr

# Usage: _ec_error MESSAGE...
# Prints MESSAGE (a la echo) with an error prefix to stderr.
function _ec_error {
    echo >>${_ec_output} $0: error: "$@"
}

# Usage: _ec_warn MESSAGE...
# Prints MESSAGE (a la echo) with a warning prefix to stderr.
function _ec_warn {
    echo >>${_ec_output} $0: warning: "$@"
}

# Usage: _ec_fail MESSAGE...
# Prints MESSAGE (a la echo) with an error prefix to stderr and exits.
function _ec_fail {
    _ec_error "$@"
    exit 1
}

# Usage require_vars VAR_NAME...
#
# Checks that each environment variable name given is set to a
# non-empty value. After all variables have been checked (and error
# messages emitted), if any var was not set, exits the shell with
# error status.
function require_vars {
    local missing=false
    while [[ -n "$1" ]]; do
        local name="$1"
        local value=`eval echo \"'$'$name\"`
        if [[ -z "$value" ]]; then
            _ec_error "required environment variable ${name} not set"
            missing=true
        fi
        shift
    done

    if $missing; then
        exit 1
    fi
}

# Usage: rewrite_vars FROM TO
#
# Finds all environment variables starting with FROM and re-exports
# their values with TO substituted for FROM unless the TO-prefixed
# variable is already defined. Because this function uses eval,
# environment variable names are only allowed to contain upper case
# letter, numbers, and underscores to avoid bugs related to escaping.
function rewrite_vars {
    local FROM="$1"
    local TO="$2"

    if [ -z "${FROM}" ]; then
        _ec_fail "convert does not handle empty FROM prefixes."
        return
    fi

    if [[ "${FROM}" != `echo "${FROM}" | tr -C -d '[A-Z0-9_]'` ]]; then
        _ec_fail "convert FROM value (${FROM}) must match [A-Z0-9_]+"
        return
    fi

    if [[ "${TO}" != `echo "${TO}" | tr -C -d '[A-Z0-9_]'` ]]; then
        _ec_fail "convert TO value (${TO}) must match [A-Z0-9_]*"
        return
    fi

    for fvar in `eval echo \"'$'{\!${FROM}@}\"`; do
        if [[ "${fvar}" == `echo "${fvar}" | tr -C -d '[A-Z0-9_]'` ]]; then
            # generate replacement name
            local tvar=${fvar/#${FROM}/${TO}}

            local tvalue=`eval echo \"'$'${tvar}\"`
            if [[ -z "${tvalue}" ]]; then
                local fvalue=`eval echo \"'$'${fvar}\"`
                export ${tvar}="${fvalue}"
            fi
        else
            _ec_warn "ignoring environment variable ${fvar}"
        fi
    done
}
