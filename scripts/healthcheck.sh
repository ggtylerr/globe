#!/bin/bash
scriptDir=$(dirname "$(readlink -f "$0")")

# TODO: Check if domains are reachable
for srv in "$scriptDir/../services/"*; do
  srv=${srv%*/}
  cd $srv
  if docker compose ps | grep -q "unhealthy"; then
    name=${srv##*/}
    echo "Service $name is unhealthy. Restarting..."
    docker compose down
    docker compose up -d
    if name == "invidious"; then
      $scriptDir/rotate.sh
    fi
    sleep 30
    if docker compose ps | grep -q "unhealthy"; then
      echo "Service $name is still unhealthy."
      curl -H "Priority: urgent" -d "Service $name is unhealthy despite restart!" ntfy.sh/$(<$scriptDir/ntfy.txt)
    fi
  fi
done