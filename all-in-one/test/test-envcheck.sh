#!/bin/bash

SCRIPT_DIR=$(cd `dirname $0` && pwd)

TEMP_DIR=$(mktemp -d -t `basename $0`-XXXXXX)
if [ -z "$TEMP_DIR" ]; then
    echo >/dev/stderr "could not create temp dir"
    exit 1
fi
trap "rm -rf '${TEMP_DIR}'" EXIT

# Remove any functions starting with "test_" from the environment
# (otherwise we'll blindly invoke them).
for t in `declare -f | grep -E "^test_" | tr -d '[() ]'`; do
    unset "$t"
done

# Count number of passed and failed assertions.
let PASSES=0
let FAILURES=0

# Log a failed assertion. Arguments are output as the error message
# along with a "stack".
function _fail {
    echo >/dev/stderr "$@"
    if [ ${#FUNCNAME[@]} -gt 2 ]; then
        for ((i=1;i<${#FUNCNAME[@]}-1;i++)); do
            echo " $i: ${BASH_SOURCE[$i+1]}:${BASH_LINENO[$i]} ${FUNCNAME[$i]}(...)"
        done
    fi

    let FAILURES=FAILURES+1
}

# Assert $1 == $2
function _assert_eq {
    if [[ $# != 2 ]]; then
        _fail _assert_eq called with $# args: "$@"
        return 1
    fi

    if [[ "$1" != "$2" ]]; then
        _fail "`cat <<EOF
_assert_eq failed:
	"$1"
does not equal
	"$2"
EOF`"
        return 1
    fi

    let PASSES=PASSES+1
    return 0
}

# Assert empty array (e.g., _assert_empty "${ARRAY[@}]}")
function _assert_empty {
    local arr=("$@")
    if [[ ${#arr[@]} != 0 ]]; then
        _fail _assert_empty failed: "'""${arr[@]}""'" is not empty
        return 1
    fi

    let PASSES=PASSES+1
    return 0
}

# Assert $1 is an empty file.
function _assert_empty_file {
    if [[ $# != 1 ]]; then
        _fail _assert_empty_file called with $# args: "$@"
        return 1
    fi

    if [[ ! -r "$1" ]]; then
        _fail _assert_empty_file failed: "$1" is not readable
        return 1
    fi

    if [[ `cat "$1"` != "" ]]; then
        _fail _assert_empty_file failed: "$1" is not empty
        return 1
    fi

    let PASSES=PASSES+1
    return 0
}

# Configure envcheck.sh output to go to OUTPUT_FILE instead of
# /dev/stderr.
OUTPUT_FILE=$(mktemp "${TEMP_DIR}/output.XXXXXXXX")
_ec_output="${OUTPUT_FILE}"

# Prevent envcheck.sh exit calls from actually exiting and record
# their exit codes.
EXIT_CALLS=()
function exit {
    EXIT_CALLS[${#EXIT_CALLS[@]}]="$1"
}

# Resets the OUTPUT_FILE and EXIT_CALLS.
function _reset {
    echo -n >"${OUTPUT_FILE}"
    EXIT_CALLS=()
}

source "${SCRIPT_DIR}/../scripts/envcheck.sh"

##############
# Test cases #
##############

function test_ec_error {
    local word=foo
    _ec_error the word is: $word
    _assert_eq "`cat "${OUTPUT_FILE}"`" "$0: error: the word is: foo"
    _assert_empty "${EXIT_CALLS[@]}"
}

function test_ec_warning {
    local word=foo
    _ec_warn the word is: $word
    _assert_eq "`cat "${OUTPUT_FILE}"`" "$0: warning: the word is: foo"
    _assert_empty "${EXIT_CALLS[@]}"
}

function test_ec_fail {
    local word=foo
    _ec_fail the word is: $word
    _assert_eq "`cat "${OUTPUT_FILE}"`" "$0: error: the word is: foo"
    _assert_eq "${#EXIT_CALLS[@]}" "1"
    _assert_eq "${EXIT_CALLS[0]}" "1"
}

function test_require_vars {
    FOO1=x
    FOO2=y
    FOO3=z
    require_vars FOO1
    require_vars FOO1 FOO2
    require_vars FOO1 FOO2 FOO3
    _assert_empty "${EXIT_CALLS[@]}"
    _assert_empty_file "${OUTPUT_FILE}"
}

function test_require_vars_missing_first {
    FOO3=x
    require_vars FOO1 FOO2 FOO3
    _assert_eq "`cat "${OUTPUT_FILE}"`" "`cat <<EOF
$0: error: required environment variable FOO1 not set
$0: error: required environment variable FOO2 not set
EOF`"
    _assert_eq "${#EXIT_CALLS[@]}" "1"
    _assert_eq "${EXIT_CALLS[0]}" "1"
}

function test_require_vars_missing_last {
    FOO1=x
    require_vars FOO1 FOO2 FOO3
    _assert_eq "`cat "${OUTPUT_FILE}"`" "`cat <<EOF
$0: error: required environment variable FOO2 not set
$0: error: required environment variable FOO3 not set
EOF`"
    _assert_eq "${#EXIT_CALLS[@]}" "1"
    _assert_eq "${EXIT_CALLS[0]}" "1"
}

function test_rewrite_vars_bad_args {
    rewrite_vars "" "OK"
    _assert_eq "`cat "${OUTPUT_FILE}"`" "$0: error: convert does not handle empty FROM prefixes."
    _assert_eq "${#EXIT_CALLS[@]}" "1"
    _assert_eq "${EXIT_CALLS[0]}" "1"

    _reset
    rewrite_vars "nope" "OK"
    _assert_eq "`cat "${OUTPUT_FILE}"`" "$0: error: convert FROM value (nope) must match [A-Z0-9_]+"
    _assert_eq "${#EXIT_CALLS[@]}" "1"
    _assert_eq "${EXIT_CALLS[0]}" "1"

    _reset
    rewrite_vars "OK" "nope"
    _assert_eq "`cat "${OUTPUT_FILE}"`" "$0: error: convert TO value (nope) must match [A-Z0-9_]*"
    _assert_eq "${#EXIT_CALLS[@]}" "1"
    _assert_eq "${EXIT_CALLS[0]}" "1"
}

function test_rewrite_vars {
    FOO_VAR=abc
    FOOBAR_VAR=123

    rewrite_vars "FOO" "BAZ"
    cat $OUTPUT_FILE
    _assert_eq "${BAZ_VAR}" "abc"
    _assert_eq "${BAZBAR_VAR}" "123"

    _assert_empty "${EXIT_CALLS[@]}"
    _assert_empty_file "${OUTPUT_FILE}"
}

function test_rewrite_vars_skip_existing {
    FOO_VAR1=abc
    FOO_VAR2=def
    BAZ_VAR2=already-set

    rewrite_vars "FOO_" "BAZ_"
    cat $OUTPUT_FILE
    _assert_eq "${BAZ_VAR1}" "abc"
    _assert_eq "${BAZ_VAR2}" "already-set"

    _assert_empty "${EXIT_CALLS[@]}"
    _assert_empty_file "${OUTPUT_FILE}"
}

function test_rewrite_vars_strip_prefix {
    FOO_FOOVAR=abc

    rewrite_vars "FOO_" ""
    cat $OUTPUT_FILE
    _assert_eq "${FOOVAR}" "abc"

    _assert_empty "${EXIT_CALLS[@]}"
    _assert_empty_file "${OUTPUT_FILE}"
}

SAVE_ENV=$(mktemp "${TEMP_DIR}/saveenv.XXXXXXXX")
POST_ENV=$(mktemp "${TEMP_DIR}/postenv.XXXXXXXX")

# Count tests, failed tests, and passed tests.
let TESTS=0
let FAILED_TESTS=0
let PASSED_TESTS=0

# Iterate over functions starting with "test_"
for t in `declare -f | grep -E "^test_" | tr -d '[() ]'`; do
    let TESTS=TESTS+1
    let FAILURES=0
    let PASSES=0

    # Save current shell and environment variables
    compgen -v | sort >$SAVE_ENV

    echo "=== RUN  $t"
    _reset
    $t
    if [[ $FAILURES -gt 0 ]]; then
        let FAILED_TESTS=FAILED_TESTS+1
        echo "--- FAIL: $t"
    elif [[ $PASSES == 0 ]]; then
        let FAILED_TESTS=FAILED_TESTS+1
        echo "No assertions made."
        echo "--- FAIL: $t"
    else
        let PASSED_TESTS=PASSED_TESTS+1
        echo "--- PASS: $t"
    fi

    # Remove any shell or environment variables introduced by the test.
    compgen -v | sort >$POST_ENV
    for v in `comm -1 -3 "${SAVE_ENV}" "${POST_ENV}"`; do
        unset "${v}"
    done
done

# Restore exit for our own purposes.
unset exit
if [[ $TESTS == 0 ]]; then
    echo FAILED: NO TESTS FOUND
    exit 2
fi

if [[ $TESTS != $PASSED_TESTS ]]; then
    echo FAILED
    exit 1
fi

echo OK
