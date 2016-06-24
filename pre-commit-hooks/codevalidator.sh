#!/usr/bin/env bash
#
FILES_PATTERN=\
".*\.(yaml|yml|json|rb|erb|sql|sh|xml|\
java|jsp|vm|properties|\
html|less|css|php|js)|\
Gemfile|Brewfile.*|Vagrantfile$"

# PY_PATTERN=".*\.(py)"

for f in $(git diff git --cached --name-only | grep -E "$FILES_PATTERN"); do
    if ! codevalidator -f -v "$f"; then
        exit 1
    fi
done

# for f in $(git diff --cached --name-only | grep -E "$PY_PATTERN"); do
#     if ! codevalidator -a pythontidy -v "$f"; then
#         exit 1
#     fi
# done
