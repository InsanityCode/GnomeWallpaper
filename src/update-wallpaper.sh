#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")"

wpdir=~/Pictures/GnomeWallpaper/
mkdir -p "$wpdir"

wallpapers_folder=~/Pictures/Wallpapers/
config=${wpdir}config.ini

new_config=${wpdir}new_config.ini
>"$new_config"

spanned=$(realpath "${wpdir}wallpaper.png")
new_spanned=$(realpath "${wpdir}new_wallpaper.png")

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
    gsettings set org.gnome.desktop.background picture-options "zoom"
    echo "$k_display$display=$wallpaper" > "$config"
}

min()
{
    if (( $1 < $2 )); then
        echo $1
    else
        echo $2
    fi
}

max()
{
    if (( $1 < $2 )); then
        echo $2
    else
        echo $1
    fi
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

    # TODO even if no prior config exists, avoid using the same wallpaper on multiple screens

    local min_x=0
    local max_x=0
    local min_y=0
    local max_y=0

    local args=
    for i in "${!screens[@]}"; do
        local screen="${screens[$i]}"

        if [[ "$screen" =~ ^([^[:space:]]+)[[:space:]][^[:digit:]]+[[:space:]]([[:digit:]]+)x([[:digit:]]+)\+([[:digit:]]+)\+([[:digit:]]+) ]]; then
            local display=${BASH_REMATCH[1]}
            local w=${BASH_REMATCH[2]}
            local h=${BASH_REMATCH[3]}
            local lo_x=${BASH_REMATCH[4]}
            local lo_y=${BASH_REMATCH[5]}
        else
            # can't parse displays, use single display mode
            set_single_display_wallpaper "$screen"
            return
        fi

        local hi_x=$(( lo_x + w ))
        local hi_y=$(( lo_y + h ))

        if (( hi_x > min_x && hi_y > min_y && lo_x < max_x && lo_y < max_y )); then
            # displays intersect (e.g. mirrored), use single display mode
            set_single_display_wallpaper "$screen"
            return
        fi

        min_x=$(min $lo_x $min_x)
        max_x=$(max $hi_x $max_x)
        min_y=$(min $lo_y $min_y)
        max_y=$(max $hi_y $max_y)

        local current=$(get_current_wallpaper "$display")

        local wallpaper=
        if [[ $i -eq $update || $update -lt 0 || -z $current ]]; then
            wallpaper=$(get_random_wallpaper "$display" "screens[@]")
        else
            wallpaper=$current
        fi

        args="$args '$wallpaper' $lo_x $lo_y $w $h"
        echo "$k_display$display=$wallpaper" >> "$new_config"
    done

    eval python3 ./create-span.py "$new_spanned" $args

    if [ -n "$new_spanned" ]; then
        mv -f "$new_spanned" "$spanned"
        gsettings set org.gnome.desktop.background picture-uri-dark "file://$spanned"
        gsettings set org.gnome.desktop.background picture-options "spanned"
        mv "$new_config" "$config"
    fi
}

screens="$(xrandr --query | grep -P '^\s*\w+\s+connected.*\+(\d+)\+(\d+)')"
num_screens=$(echo "$screens" | wc -l)

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
