#!/usr/bin/env bash

# Configuration
SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
CLIPBOARD=true  # Set to false to disable clipboard copy
OPEN_AFTER=false  # Set to true to open screenshot after taking it
DEFAULT_MODE="region"  # Default screenshot mode: region, output, window
QUALITY=100  # Image quality (1-100)
DELAY=0  # Delay in seconds before taking screenshot
NOTIFY_TIMEOUT=5000  # Notification timeout in milliseconds
EDITOR="gimp"  # Image editor to use if editing is requested

# Create screenshot directory if it doesn't exist
mkdir -p "$SCREENSHOT_DIR"

# Help function
show_help() {
    echo "Screenshot script usage:"
    echo "  -m, --mode MODE    Screenshot mode: region, output, window (default: $DEFAULT_MODE)"
    echo "  -c, --clipboard    Copy to clipboard only, don't save file"
    echo "  -s, --save         Save file only, don't copy to clipboard"
    echo "  -e, --edit         Open screenshot in editor after taking"
    echo "  -d, --delay SECS   Delay screenshot by SECS seconds"
    echo "  -q, --quality NUM  JPEG quality (1-100, default: $QUALITY)"
    echo "  -h, --help         Show this help"
    exit 0
}

# Process arguments
MODE="$DEFAULT_MODE"
SAVE_FILE=true
EDIT_AFTER=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--mode)
            MODE="$2"
            shift 2
            ;;
        -c|--clipboard)
            SAVE_FILE=false
            CLIPBOARD=true
            shift
            ;;
        -s|--save)
            SAVE_FILE=true
            CLIPBOARD=false
            shift
            ;;
        -e|--edit)
            EDIT_AFTER=true
            shift
            ;;
        -d|--delay)
            DELAY="$2"
            shift 2
            ;;
        -q|--quality)
            QUALITY="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            ;;
    esac
done

# Validate mode
if [[ ! "$MODE" =~ ^(region|output|window)$ ]]; then
    echo "Invalid mode: $MODE"
    show_help
fi

# Handle delay if specified
if [ "$DELAY" -gt 0 ]; then
    notify-send -t 2000 "Screenshot" "Taking screenshot in ${DELAY} seconds..."
    sleep "$DELAY"
fi

# Generate filename with timestamp
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
FILENAME="Screenshot-${TIMESTAMP}.png"
FILEPATH="${SCREENSHOT_DIR}/${FILENAME}"

# Take the screenshot
if [ "$SAVE_FILE" = true ]; then
    # Take screenshot and save to file
    hyprshot -m "$MODE" -o "$FILEPATH" -z --quality "$QUALITY"
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        # Copy to clipboard if enabled
        if [ "$CLIPBOARD" = true ]; then
            if command -v wl-copy >/dev/null 2>&1; then
                wl-copy < "$FILEPATH"
                CLIP_MSG="and copied to clipboard"
            fi
        fi

        # Show notification with preview
        notify-send -t "$NOTIFY_TIMEOUT" -i "$FILEPATH" "📸 Screenshot saved" "$FILEPATH $CLIP_MSG"

        # Open or edit if requested
        if [ "$EDIT_AFTER" = true ] && [ -f "$FILEPATH" ]; then
            "$EDITOR" "$FILEPATH" &
        elif [ "$OPEN_AFTER" = true ] && [ -f "$FILEPATH" ]; then
            xdg-open "$FILEPATH" &
        fi
    elif [ $EXIT_CODE -eq 130 ]; then
        # User canceled the screenshot (SIGINT)
        exit 0
    else
        notify-send -t "$NOTIFY_TIMEOUT" "❌ Screenshot failed" "Error code: $EXIT_CODE"
    fi
else
    # Clipboard-only mode
    hyprshot -m "$MODE" -z --quality "$QUALITY" --clipboard-only
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        notify-send -t "$NOTIFY_TIMEOUT" "📋 Screenshot copied" "Screenshot copied to clipboard"
    elif [ $EXIT_CODE -eq 130 ]; then
        # User canceled
        exit 0
    else
        notify-send -t "$NOTIFY_TIMEOUT" "❌ Screenshot failed" "Error code: $EXIT_CODE"
    fi
fi
