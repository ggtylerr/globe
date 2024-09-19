#!/bin/bash

scriptDir=$(dirname "$(readlink -f "$0")")
cd $scriptDir
echo "Checking for updates..."
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
            cd ../services
            for dir in */; do
                if [[ "$dir" == "poke/" || "$dir" == "simplytranslate/" ]]; then
                    # skip poke and simplytranslate since they are built and don't have watchtower
                    continue
                fi
                if [[ "$dir" == "cobalt/" ]]; then
                    echo "Updating $dir..."
                    cd "$dir"
                    sed -i "s/--interval [0-9]*/--interval 3600/" "docker-compose.yml"
                    docker compose restart watchtower
                    cd ..
                    continue
                fi
                if [[ "$dir" == "hyperpipe/" || "$dir" == "piped/" ]]; then
                    echo "Updating $dir..."
                    cd "$dir"
                    sed -i '/command:.*/s/$/ --interval 3600/' "docker-compose.yml"
                    docker compose restart watchtower
                    cd ..
                    continue
                fi
                if [ -f "$dir/docker-compose.yml" ]; then
                    echo "Updating $dir..."
                    cd "$dir"
                    # Tried to make this fancy but looks like this isn't working,
                    # hence the if statements up top. If anyone else can do it,
                    # feel free to PR ~ tyler
                    sed -i '/watchtower:/,/^[^ ]/{
                        /command:/ {
                            /--interval/ s/--interval [0-9]*/--interval 3600/
                            /--interval/! s/command:.*/& --interval 3600/ 
                        }
                        /command:/!{
                            /watchtower:/a \ \ \ \ command: --interval 3600
                        }
                    }' "docker-compose.yml"
                    docker compose restart watchtower
                    cd ..
                fi
            done
            cd $scriptDir
        else
            echo "No worries! Just update your configs manually with the interval 3600. See the template for details."
        fi
    fi
fi