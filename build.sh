#!/bin/bash

set -e

TOP_DIR="$(dirname $(readlink -f $0))"

function get_vulue() { # do_not_function_help
	local prefix="$1"
	local default_value="$2"
	local value="$3"
	if [ "$value"x = ""x ]; then
		echo "$default_value"
	else
		echo "$prefix$value"
	fi
}

function run_cmd() { # do_not_function_help
	local cmd="$@"

    if [ ! "$RUN_DIR"x = ""x ]; then
        cd $RUN_DIR
    fi

	echo "$cmd"
	eval $cmd

    if [ ! "$RUN_DIR"x = ""x ]; then
        cd - 2>/dev/null
    fi
}

function contain_key() { # do_not_function_help
	local key="$1"
	shift
	local keys="$@"

	local k=""
	for k in $keys;
	do
		if [ "$k"x = "$key"x ]; then
			return 0
		fi
	done

	return 1
}

function log() { # do_not_function_help
	if [ "$VERBOSE"x = "1"x ]; then
		echo "[$(date +%Y-%m-%d:%H:%M:%S)] $@"
	fi
}

function dep() {
    run_cmd pip install -r $TOP_DIR/requirements.txt
}

function run() {
    run_cmd python $TOP_DIR/bitwise_calculator.py
}

function pack() { # PARAMS
    # if [[ "$OSTYPE" == "darwin"* ]]; then
    local params="$@"
    local not_use_spec=0

    rm -rf $TOP_DIR/dist $TOP_DIR/build
    if [ $not_use_spec -eq 1 ]; then
        pyinstaller --windowed --onefile --icon=$TOP_DIR/bitwise_calculator.ico $@ $TOP_DIR/bitwise_calculator.py
    else
        pyinstaller $TOP_DIR/bitwise_calculator.spec
    fi
}


default_cmd="help"

function help() {
	local ret=$(get_vulue "" 0 $1)
	echo -e "Optional commands :"
	grep '^function ' $0 | grep -v 'do_not_function_help' | \
		sed -e 's/(//g' -e 's/)//g' -e 's/^function //' -e 's/{/ /' -e 's/#//' | \
		awk '{out=$1; for(i=2;i<=NF;i++){out=out" "$i}; print "\t"out}'
	exit $ret
}

function is_function() { # do_not_function_help
	local type=$(type -t $1 2>/dev/null)
	if [ "function"x = "$type"x ]; then
		return 0
	fi
	return 1
}

CMD=$default_cmd
if is_function $1; then
	CMD=$1
	shift
fi

$CMD $@
