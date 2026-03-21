#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")"

while true; do
    sleep 10s
    bash "./update-wallpaper.sh"
done
