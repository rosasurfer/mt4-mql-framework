#!/bin/bash
#
# TODO: The script must make sure "experts/include" exists in the compiler directory.
#
set -e


# --- functions -------------------------------------------------------------------------------------------------------------

# print a message to STDERR
function error() {
    echo "$@" 1>&2
}

# --- end of functions ------------------------------------------------------------------------------------------------------


# find the MQL compiler
SCRIPT_DIR=$(dirname "$(readlink -e "$0")")
mqlc=
[ -z "$mqlc" ] && [ -f "$SCRIPT_DIR/metalang.exe"] && mqlc="$SCRIPT_DIR/metalang.exe"
[ -z "$mqlc" ] &&  command -v metalang >/dev/null  && mqlc="metalang" 
[ -z "$mqlc" ] && { error "ERROR: MQL compiler not found."; exit 1; } 

# call it
$mqlc "$@"
