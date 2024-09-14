#!/usr/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

OUT_DIR="."
LOG_FILE="compile.log"
OPTS=""

# Create the output directory if not the current directory
[[ $OUT_DIR != "." ]] && mkdir -p "$OUT_DIR"

# Check for gcc
command -v gcc &>/dev/null || { echo -e "${RED}Error: gcc is not installed.${NC}"; exit 1; }

# Handle help
if [[ "$1" == "--help" ]]; then
  echo "Usage: $0 [OPTIONS]"
  echo "Compile all .c files in the current directory."
  echo
  echo "Options:"
  echo "  --help       Show this help message and exit"
  echo "  -o DIR       Specify output directory (default: current directory)"
  echo "  -O OPTS      Pass optimization options to gcc (e.g., -O2, -O3)"
  exit 0
fi

# Parse options
while getopts "o:O:" opt; do
  case "$opt" in
    o) OUT_DIR="$OPTARG"; mkdir -p "$OUT_DIR" ;;
    O) OPTS="$OPTARG" ;;
  esac
done

log() {
  echo "$1 at $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
}

compile() {
  local src_file="$1"
  local output_file="$OUT_DIR/$(basename "${src_file%.c}")"

  echo -e "${YELLOW}Compiling $src_file...${NC}"

  if gcc -o "$output_file" "$src_file" $OPTS; then
    echo -e "${GREEN}$src_file compiled successfully.${NC}"
    log "SUCCESS: $src_file"
  else
    echo -e "${RED}Failed to compile $src_file${NC}"
    log "FAILED: $src_file"
  fi
}

# Remove log file if it exists
[ -f $LOG_FILE ] && rm $LOG_FILE

# Compile .c files in parallel
for src_file in *.c; do
  [ -e $src_file ] || continue
  compile $src_file &
done

# Wait for all background jobs to finish
wait

echo -e "${GREEN}All modules compiled.${NC}"
echo "Log saved to $LOG_FILE"