#!/usr/bin/env bash
#
FILES_PATTERN='.*\.(yml|yaml)$'

for f in $(git diff --cached --name-only | grep -E "$FILES_PATTERN"); do
    if ! ansible-lint "$f"; then
        exit 1
    fi
done
