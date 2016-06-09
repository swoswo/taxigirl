#!/usr/bin/env bash
#
while read -r f; do
    # yaml check
    if [[ $(head -n1 "$f" ) == "---" ]]; then
        if ! ansible-lint "$f"; then
            exit 1
        fi
    fi
done < <(git diff-index --name-only HEAD)
