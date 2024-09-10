#!/bin/bash
scriptDir=$(dirname "$(readlink -f "$0")")

output=$(docker run quay.io/invidious/youtube-trusted-session-generator)

visitor_data=$(echo "$output" | grep -oP '(?<=visitor_data: )[^ ]+')
po_token=$(echo "$output" | grep -oP '(?<=po_token: )[^ ]+')

if [ -z "$visitor_data" ] || [ -z "$po_token" ]; then
  echo "Error: Could not generate visitor_data or po_token."
  exit 1
fi

sed -i "s/visitor_data: .*/visitor_data: $visitor_data/g" $scriptDir/../services/invidious/docker-compose.yml
sed -i "s/po_token: .*/po_token: $po_token/g" $scriptDir/../services/invidious/docker-compose.yml

cd $scriptDir/../services/invidious
docker compose down
docker compose up -d

echo "Successfully updated visitor_data and po_token on Invidious."
