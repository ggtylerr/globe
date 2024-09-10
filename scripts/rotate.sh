#!/bin/bash
scriptDir=$(dirname "$(readlink -f "$0")")
ipv6range=$(<$scriptDir/range.txt)

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

sudo python $scriptDir/../smart-ipv6-rotator/smart-ipv6-rotator.py run --ipv6range=$ipv6range
if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR:${NC} IP rotation failed! See above for details."
    exit 1
fi