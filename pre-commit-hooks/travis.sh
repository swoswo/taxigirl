#!/usr/bin/env bash
#
FILES_PATTERN='.travis.yml$'

for f in $(git diff --cached --name-only | grep -E "$FILES_PATTERN"); do
    if ! travis lint "$f"; then
        exit 1
    fi
done
