#!/usr/bin/env bash

if ! command -v ddcutil &> /dev/null; then
  echo "ddcutil not found"
  exit 1
fi

old_brightness=0

while true; do
  read -r current_brightness max_brightness <<< "$(ddcutil --noconfig getvcp 10 2>/dev/null | awk -F'[:,=]' '/Brightness/ {gsub(/ /, "", $0); print $3, $5}')"

  if [[ -z "$current_brightness" || -z "$max_brightness" || ! "$current_brightness" =~ ^[0-9]+$ || ! "$max_brightness" =~ ^[0-9]+$ ]]; then
    echo '{"text": " Error", "tooltip": "Failed to read brightness"}'
    sleep 1
    continue
  fi

  brightness_percentage=$(( current_brightness * 100 / max_brightness ))

  if (( brightness_percentage < 20 )); then
    brightness_icon=""
  elif (( brightness_percentage < 50 )); then
    brightness_icon=""
  elif (( brightness_percentage < 80 )); then
    brightness_icon=""
  else
    brightness_icon=""
  fi

  if (( brightness_percentage != old_brightness )); then
    echo "{\"text\": \"$brightness_icon  ${brightness_percentage}%\"}"

    pkill -RTMIN+1 waybar

    old_brightness=$brightness_percentage
  fi
done