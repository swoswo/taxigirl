#!/usr/bin/env bash
#
# TODO: abstraction
EXEC_PATTERN='.*\.(sh|bash|dash|ksh)$'
SCRIPT_PATTERN='.*\.(envrc)$'

for f in $(git diff --cached --name-only | grep -E "$EXEC_PATTERN"); do
    if ! shellcheck --color=auto "$f"; then
        exit 2
    fi
    # all files must be executable
    if [[ ! -x $f ]]; then
        echo "Error: '$f' is not executable."
        exit 1
    fi
done

for f in $(git diff --cached --name-only | grep -E "$SCRIPT_PATTERN"); do
    if ! shellcheck --color=auto --exclude=SC1008 "$f"; then
        exit 2
    fi
done
