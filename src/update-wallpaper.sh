#!/bin/bash

parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd "$parent_path"

wallpapers=~/Pictures/Wallpapers

screens="$(xrandr --query | grep -P '^\s*\w+\s+connected.*\+(\d+)\+(\d+)')"
numScreens=$(echo "$screens" | wc -l)

if [ "$numScreens" -eq 1 ]; then
    wallpaper=$(find "$wallpapers" -type f \( -name '*.jpg' -o -name '*.png' -o -name '*.jpeg' \) | shuf -n 1)
    gsettings set org.gnome.desktop.background picture-uri-dark "file://$wallpaper"
    gsettings set org.gnome.desktop.background picture-options "spanned"

else
    sizes="$(echo "$screens" | grep -oP '\d+x\d+' | tr 'x' ' ')"
    offsets="$(echo "$screens" | grep -oP '\+\d+\+\d+' | tr '+' ' ')"

    args=
    for ((i = 0; i < $numScreens; i++)); do
        wallpaper=$(find "$wallpapers" -type f \( -name '*.jpg' -o -name '*.png' -o -name '*.jpeg' \) | shuf -n 1)
        offset=$(echo "$sizes" | sed -n "$((i + 1))p")
        size=$(echo "$offsets" | sed -n "$((i + 1))p")
        args="$args '$wallpaper' $size $offset"
    done

    dir=~/Pictures/GnomeWallpaper
    mkdir -p "$dir"

    spanned=$(realpath "$dir/wallpaper.png")

    eval python3 ./create-span.py "$spanned" $args

    if [ -n "$spanned" ]; then

        gsettings set org.gnome.desktop.background picture-uri-dark "file://$spanned"
        gsettings set org.gnome.desktop.background picture-options "spanned"

        echo "Changed wallpaper to: $spanned"
    fi
fi
