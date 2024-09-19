#!/bin/bash

scriptDir=$(dirname "$(readlink -f "$0")")
cd $scriptDir
git pull

VERSION_CODE=$(cat version-code.txt)
LATEST_VERS=$(cat version-code.latest.txt)

if [ "$VERSION_CODE" -lt "$LATEST_VERS" ]; then
    echo "New version available with migrations!"
    cp version-code.latest.txt version-code.txt
    if [ "$VERSION_CODE" -eq 0 ]; then
        echo "In version 1, we updated the Watchtower config to have an interval of 1 hour, instead of the default 24."
        read -p "Would you like to update this automatically? (Y/n)" -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo "Updating now..."
            for dir in */; do
                if [[ "$dir" == "poke/" || "$dir" == "simplytranslate/" ]]; then
                    # skip poke and simplytranslate since they are built and don't have watchtower
                    continue
                fi
                if [ -f "$dir/docker-compose.yml" ]; then
                    echo "Updating $dir..."
                    if grep -q "watchtower" "$dir/docker-compose.yml"; then
                        if grep -q "command: --interval" "$dir/docker-compose.yml"; then
                            sed -i 's/command: --interval [0-9]*/command: --interval 3600/' "$dir/docker-compose.yml"
                        else
                            sed -i '/watchtower/a \ \ \ \ command: --interval 3600' "$dir/docker-compose.yml"
                        fi
                    fi
                fi
            done
        else
            echo "No worries! Just update your configs manually with the interval 3600. See the template for details."
        fi
    fi
fi