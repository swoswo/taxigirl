#!/usr/bin/env bash
#
while read -r f; do
    # sh check
    if [[ $(head -n1 "$f" ) == *sh ]]; then
        if ! bashate "$f"; then
            exit 1
        fi
        # all files must be executable
        if [[ ! -x $f ]]; then
            echo "Error: '$f' is not executable!"
            exit 1
        fi
    fi
done < <(git diff-index --name-only HEAD)
