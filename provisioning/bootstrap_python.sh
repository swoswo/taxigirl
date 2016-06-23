#!/usr/bin/env sh
# https://gist.github.com/gretel/7a76a3fe1e15a8a8e0c37457d18e795a
# 2016 tom hensel <github@jitter.eu>
# this script ensures `python-2.7` gets installed so `ansible` can be (on debian)
# i.e. in a `Vagrantfile`:
#  config.vm.provision 'Bootstrap Python', type: 'shell', path: 'scripts/bootstrap_python.sh', args: ['2.7', 'python python-pkg-resources']
#

find_pyver="$1"
if [ -z "$find_pyver" ]; then
    printf "Usage:\n  %s: <match_substring>\n\
        Example:\n  $ %s 2.7 'python python-pkg-resources'\n" "$0" "$0"
    exit 1
fi

have_pyver="$(python -V 2>&1)"
if echo "$have_pyver" | grep -q "$1"; then
    printf "%s is installed.\n" "$have_pyver"
    exit 0
else
    printf "Could not find any version matching '%s'.\n" "$have_pyver"
fi

if [ -n "$2" ]; then
    printf "Installing: %s\n" "$2"
    apt-get -qq install --no-install-recommends "${2}" || exit 2
fi
