#!/usr/bin/env bash

if ! command -v ddcutil &>/dev/null; then
  echo "ddcutil not found"
  exit 1
fi

old_brightness=-1

while true; do
  output=$(ddcutil --noconfig getvcp 10 2>/dev/null)
  
  # Extract brightness values
  current_brightness=$(awk -F'=' '/current value/ {gsub(/[^0-9]/, "", $2); print $2}' <<< "$output")
  max_brightness=$(awk -F'=' '/max value/ {gsub(/[^0-9]/, "", $3); print $3}' <<< "$output")

  # Fallback if parsing failed
  if [[ ! "$current_brightness" =~ ^[0-9]+$ || ! "$max_brightness" =~ ^[0-9]+$ || "$max_brightness" -eq 0 ]]; then
    echo '{"text": " Error", "tooltip": "Failed to read brightness"}'
    sleep 0.5
    continue
  fi

  brightness_percentage=$(( current_brightness * 100 / max_brightness ))

  if (( brightness_percentage != old_brightness )); then
    if (( brightness_percentage < 20 )); then
      brightness_icon=""
    elif (( brightness_percentage < 50 )); then
      brightness_icon=""
    elif (( brightness_percentage < 80 )); then
      brightness_icon=""
    else
      brightness_icon=""
    fi

    echo "{\"text\": \"$brightness_icon  ${brightness_percentage}%\"}"

    pkill -RTMIN+1 waybar

    old_brightness=$brightness_percentage
  fi

  sleep 0.1
done
11