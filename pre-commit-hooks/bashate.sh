#!/usr/bin/env bash
#
FILES_PATTERN='.*\.(sh|bash|envrc)$'

for f in $(git diff --cached --name-only | grep -E "$FILES_PATTERN"); do
    if ! bashate "$f"; then
        exit 1
    fi
done
