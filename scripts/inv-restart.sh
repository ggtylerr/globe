#!/bin/bash

for i in $(seq 1 5); do
    docker restart invidious-invidious-$i
    sleep 30
done