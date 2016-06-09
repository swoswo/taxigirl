#!/usr/bin/env bash
#
while read -r f; do
    if ! codevalidator "$f"; then
        exit 1
    fi
done < <(git diff-index --name-only HEAD)
