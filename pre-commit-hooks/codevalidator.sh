#!/usr/bin/env bash
#
FILES_PATTERN=\
".*\.(yaml|yml|json|py|rb|erb|sql|sh|xml|\
java|jsp|vm|properties|\
html|less|css|php|js)|\
Gemfile|Brewfile.*|Vagrantfile$"

for f in $(git diff --cached --name-only | grep -E "$FILES_PATTERN"); do
    if ! codevalidator -f -v "$f"; then
        exit 1
    fi
done
