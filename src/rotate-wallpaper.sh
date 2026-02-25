#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")"

while true; do
    bash "./update-wallpaper.sh"
    sleep 10s
done
