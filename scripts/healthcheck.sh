#!/bin/bash
scriptDir=$(dirname "$(readlink -f "$0")")

for srv in "$scriptDir/../services/"*; do
  srv=${srv%*/}
  cd $srv
  if [ ! -f "docker-compose.yml" ]; then
    continue
  fi
  if docker compose ps | grep -q "unhealthy"; then
    name=${srv##*/}
    echo "Service $name is unhealthy. Restarting..."
    docker compose down
    docker compose up -d
    if $name == "invidious"; then
      $scriptDir/rotate.sh
    fi
    sleep 30
    if docker compose ps | grep -q "unhealthy"; then
      echo "Service $name is still unhealthy."
      curl -H "Priority: urgent" -d "Service $name is unhealthy despite restart!" ntfy.sh/$(<$scriptDir/ntfy.txt)
    fi
  elif docker compose ps | wc -l -eq 1; then
    # nothing's running
    echo "Service $name isn't running. Starting..."
    docker compose up -d
    if $name == "invidious"; then
      $scriptDir/rotate.sh
    fi
    sleep 30
    if docker compose ps | grep -q "unhealthy"; then
      echo "Service $name is still unhealthy."
      curl -H "Priority: urgent" -d "Service $name is unhealthy despite restart!" ntfy.sh/$(<$scriptDir/ntfy.txt)
    fi
  fi
  if [ -f "domain.txt" ]; then
    while IFS= read -r link; do
      url="https://$link"
      status_code=$(curl -s -o /dev/null -w "%{http_code}" "$url")
      if [ "$status_code" -eq 502 ]; then
        echo "Service $name is 502 over $link"
        docker compose down && docker compose up -d
        if $name == "invidious"; then
          $scriptDir/rotate.sh
        fi
        sleep 30
        status_code=$(curl -s -o /dev/null -w "%{http_code}" "$url")
        if [ "$status_code" -eq 502 ]; then
          echo "Service $name is still 502ing"
          curl -H "Priority: urgent" -d "Service $name cannot be reached over $link!" ntfy.sh/$(<$scriptDir/ntfy.txt)
        fi
      fi
    done < "domain.txt"
  fi
done