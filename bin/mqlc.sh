#!/bin/bash
#


# find the MQL compiler
SCRIPT_DIR=$(dirname "$(readlink -e "$0")")
mqlc=
[ -z "$mqlc" ] && [ -f "$SCRIPT_DIR/metalang.exe"   ] && mqlc="$SCRIPT_DIR/metalang.exe"
[ -z "$mqlc" ] && command -v metalang >/dev/null      && mqlc="metalang" 

[ -z "$mqlc" ] && [ -f "$SCRIPT_DIR/metaeditor.exe" ] && mqlc="$SCRIPT_DIR/metaeditor.exe"
[ -z "$mqlc" ] && command -v metaeditor >/dev/null    && mqlc="metaeditor" 

[ -z "$mqlc" ] && { echo "ERROR: MQL compiler not found."; exit 1; } 


# call it
"$mqlc" "$@"
