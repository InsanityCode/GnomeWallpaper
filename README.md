# GnomeWallpaper
A simple tool for gnome based desktop environments, that selects random images from your `~/Pictures/Wallpapers/` folder for use as your desktop wallpaper while avoiding direct repetition or assigning the same image to multiple screens.

## Single Screen
If you have one screen, it simply sets the selected image as your wallpaper.

## Multi Screen
If you have multiple screens, this tool will select a set of wallpapers and generate a spanned wallpaper from them, considering the placement and size of the connected displays. For every consecutive update another screen will have its wallpaper changed.

## Notes
This tool does not yet respect aspect ratio, so it works best, if the wallpapers match your screen. For multi screen setups this implies that all screens need to have the same aspect ratio.

## Usage
Call [update-wallpaper.sh](./src/update-wallpaper.sh) to change your wallpaper once. Call [rotate-wallpaper.sh](./src/rotate-wallpaper.sh) to have it cycle through available wallpapers at a predefined interval (adjust the sleep interval as you please). Either of these scripts can be run automatically by creating a `.desktop` file for it in `~/.config/autostart/`.

## Dependencies
The goal of this tool is to be as lightweight as possible, so its only dependencies are usually installed by default on any gnome based linux distribution.

| Dependency     | Why?                                                |
| :------------- | :-------------------------------------------------- |
| gsettings      | For setting a desktop wallpaper.                    |
| xrandr         | For querying connected displays.                    |
| python3-pillow | For creating spanned images for multiscreen setups. |
