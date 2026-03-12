#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")"

wpdir=~/Pictures/GnomeWallpaper/
mkdir -p "$wpdir"

wallpapers_folder=~/Pictures/Wallpapers/
config=${wpdir}config.ini

new_config=${wpdir}new_config.ini
>"$new_config"

k_display=display_
k_last_updated=last_updated

# @brief    return the path to the currently set wallpaper for the specified display
# @param $1 the name of the display to retrieve the currently set wallpaper for
# @return   the path to the currently set wallpaper or an empty string if unknown
get_current_wallpaper()
{
    if [[ -f "$config" ]]; then
        local value=$(grep "^$k_display$1=" "$config" | cut -d'=' -f2-)

        if [[ -n "$value" ]]; then
            echo "$value"
        else
            echo ""
        fi
    else
        echo ""
    fi
}

# @brief    return a random wallpaper for the specified display
# @param $1 the name of the display to retrieve a new wallpaper for
# @param $2 an array of connected screens as yielded by `xrandr --query | grep "connected"`
# @return   the path to the new wallpaper or an empty string if there are no wallpapers
get_random_wallpaper()
{
    # get all available wallpapers
    local wallpapers=$(find "$wallpapers_folder" -type f \( -name '*.jpg' -o -name '*.png' -o -name '*.jpeg' \))

    local num_wallpapers=$(echo "$wallpapers" | wc -l)
    if [[ $num_wallpapers -eq 0 ]]; then
        # there are no wallpapers
        echo ""
        return
    elif [[ $num_wallpapers -eq 1 ]]; then
        # there is only one wallpaper
        echo "${wallpapers[0]}"
        return
    fi

    # remove the currently set wallpaper from the choices
    local current=$(get_current_wallpaper "$1")
    if [ -n "$current" ]; then
        wallpapers=$(printf '%s\n' "$wallpapers" | grep -vF "$current")
    fi

    # as long as there are enough wallpapers left, remove wallpapers used on other displays from the choices
    local screens_ref=("${!2}")
    for screen in "${screens_ref[@]}"; do
        num_wallpapers=$(echo "$wallpapers" | wc -l)
        if [[ $num_wallpapers -eq 1 ]]; then
            # there aren't enough wallpapers for all the screens, use the last remaining
            # TODO: use the wallpaper currently used on the least displays
            break
        fi

        local display=$(get_display_name "$screen")
        local current=$(get_current_wallpaper "$display")
        if [[ -n $current ]]; then
            wallpapers=$(printf '%s\n' "$wallpapers" | grep -vF "$current")
        fi
    done

    local random=$(echo "$wallpapers" | shuf -n 1)
    echo "$random"
}

# @brief    return the display name from the specified xrandr output line
# @param $1 a single output line from `xrandr --query | grep "connected"`
# @return   the name of the display
get_display_name()
{
    echo "$1" | awk -F' connected' '{print $1}'
}

# @brief    set a new random wallpaper for a single display
# @param $1 the `xrandr --query` line for the display
set_single_display_wallpaper()
{
    local display=$(get_display_name "$1")
    local wallpaper=$(get_random_wallpaper "$display")
    gsettings set org.gnome.desktop.background picture-uri-dark "file://$wallpaper"
    gsettings set org.gnome.desktop.background picture-options "spanned"
    echo "$k_display$display=$wallpaper" > "$config"
}

# @brief    set a new random wallpaper for every of the specified displays
# @param $1 the `xrandr --query` lines for the displays
# @param $2 the index of the display to be updated or -1 to update all
set_multi_display_wallpaper()
{
    local IFS=$'\n'

    local -a screens
    read -r -d '' -a screens <<< "$1"

    local update=$2
    echo "$k_last_updated=$update" >> "$new_config"

    local args=
    for i in "${!screens[@]}"; do
        local screen="${screens[$i]}"
        local display=$(get_display_name "$screen")
        local size="$(echo "$screen" | grep -oP '\+\d+\+\d+' | tr '+' ' ')"
        local offset="$(echo "$screen" | grep -oP '\d+x\d+' | tr 'x' ' ')"

        local current=$(get_current_wallpaper "$display")

        local wallpaper=
        if [[ $i -eq $update || $update -lt 0 || -z $current ]]; then
            wallpaper=$(get_random_wallpaper "$display" "screens[@]")
        else
            wallpaper=$current
        fi

        args="$args '$wallpaper' $size $offset"
        echo "$k_display$display=$wallpaper" >> "$new_config"
    done

    local spanned=$(realpath "${wpdir}wallpaper.png")
    eval python3 ./create-span.py "$spanned" $args

    if [ -n "$spanned" ]; then
        gsettings set org.gnome.desktop.background picture-uri-dark "file://$spanned"
        gsettings set org.gnome.desktop.background picture-options "spanned"
        mv "$new_config" "$config"
    fi
}

screens="$(xrandr --query | grep -P '^\s*\w+\s+connected.*\+(\d+)\+(\d+)')"
num_screens=$(echo "$screens" | wc -l)

# TODO: Make mirrored displays use the single wallpaper approach
#       Currently it detects multiple displays and creates a "spanned"
#       wallpaper with multiple images in the same place.
#       While this technically works, it's needlessly expensive.
if [ "$num_screens" -eq 1 ]; then
    set_single_display_wallpaper "$screens"
else
    if [[ -f "$config" ]]; then
        last_updated=$(grep "^$k_last_updated=" "$config" | cut -d'=' -f2-)
    else
        last_updated=-1
    fi
    set_multi_display_wallpaper "$screens" $(( ($last_updated + 1) % $num_screens))
fi
