#!/usr/bin/env bash

# Screenshot directory
screenshot_dir="$HOME/Pictures/Screenshots"
mkdir -p "$screenshot_dir"

# Filename with timestamp
timestamp=$(date +%Y-%m-%d_%H-%M-%S)
filename="Screenshot-${timestamp}.png"
filepath="${screenshot_dir}/${filename}"

# Take the screenshot
hyprshot -m region -z -o "$filepath" && notify-send "📸 Screenshot saved" "$filepath" || notify-send "❌ Screenshot failed"