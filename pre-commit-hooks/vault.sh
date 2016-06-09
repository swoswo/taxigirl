#!/usr/bin/env bash
#
# Pre-commit hook that verifies if all files containing 'vault'
# in the name are encrypted.
# If not, commit will fail with a message.

FILES_PATTERN='.*vault.*'
REQUIRED='ANSIBLE_VAULT'

EXIT_STATUS=0
wipe="\033[1m\033[0m"
yellow='\033[1;33m'
# carriage return hack. Leave it on 2 lines.
cr='
'
for f in $(git diff --cached --name-only | grep -E "$FILES_PATTERN"); do
    # test for the presence of the required bit.
    MATCH=$(head -n1 "$f" | grep --no-messages "$REQUIRED")
    if [ ! "$MATCH" ] ; then
        # build the list of unencrypted files if any
        UNENCRYPTED_FILES="$f$cr$UNENCRYPTED_FILES"
        EXIT_STATUS=1
    fi
done

if [ $EXIT_STATUS != 0 ] ; then
    echo 'Looks like unencrypted vault files are part of the commit:'
    while read -r line; do
        if [ -n "$line" ]; then
            printf "#\t%sunencrypted: %s" "${yellow}" "$line${wipe}"
        fi
    done <<< "$UNENCRYPTED_FILES"
    exit $EXIT_STATUS
fi

exit $EXIT_STATUS
