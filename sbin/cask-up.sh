#!/usr/bin/env bash
#
casks=( $(brew cask list) )

for cask in "${casks[@]}"; do
    installed="$(brew cask info "$cask" | grep 'Not installed')"
    if [[ $installed = *[!\ ]* ]]; then
        brew cask install "$cask" --force
    fi
done
