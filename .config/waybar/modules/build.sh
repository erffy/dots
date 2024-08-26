#!/usr/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

OUT_DIR="."
LOG_FILE="compile.log"

[[ -n $OUT_DIR ]] && mkdir -p $OUT_DIR

if ! command -v gcc &>/dev/null; then
  echo -e "${RED}Error: gcc is not installed. Please install gcc to proceed.${NC}"
  exit 1
fi

if [[ "$1" == "--help" ]]; then
  echo "Usage: $0 [OPTIONS]"
  echo "Compile all .c files in the current directory."
  echo
  echo "Options:"
  echo "  --help       Show this help message and exit"
  echo "  -o DIR       Specify output directory (default: ./bin)"
  echo "  -O OPTS      Pass optimization options to gcc (e.g., -O2, -O3)"
  exit 0
fi

while getopts "o:O:" opt; do
  case "$opt" in
  o) OUT_DIR="$OPTARG" ;;
  O) OPTS="$OPTARG" ;;
  esac
done

compile() {
  local src_file="$1"
  local output_file="$OUT_DIR/$(basename "${src_file%.c}")"

  echo -e "${YELLOW}Compiling $src_file...${NC}"

  local build_time=$(date '+%m/%d/%Y %I:%M:%S %p')

  if gcc -o "$output_file" "$src_file" $OPTS; then
    echo -e "${GREEN}$src_file compiled successfully.${NC}"
    echo "SUCCESS: $src_file at $build_time" >>$LOG_FILE
  else
    echo -e "${RED}Failed to compile $src_file${NC}"
    echo "FAILED: $src_file at $build_time" >>$LOG_FILE
  fi
}

rm $LOG_FILE

for src_file in *.c; do
  [ -e "$src_file" ] || continue
  compile "$src_file" &
done

wait

echo -e "${GREEN}All modules compiled.${NC}"
echo "Log saved to $LOG_FILE"
