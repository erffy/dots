#!/usr/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

OUT_DIR="."
LOG_FILE="compile.log"
MAX_JOBS=$(nproc)

[[ $OUT_DIR != "." ]] && mkdir -p "$OUT_DIR"

command -v gcc &>/dev/null || { echo -e "${RED}Error: gcc is not installed.${NC}"; exit 1; }

if [[ "$1" == "--help" ]]; then
  echo "Usage: $0"
  echo "Compile all .c files in the current directory."
  exit 0
fi

log() {
  echo "$1 at $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
}

compile() {
  local src_file="$1"
  local output_file="$OUT_DIR/$(basename "${src_file%.c}")"

  echo -e "${YELLOW}Compiling $src_file...${NC}"

  if gcc -o $output_file $src_file; then
    echo -e "${GREEN}$src_file compiled successfully.${NC}"
    log "SUCCESS: $src_file"
  else
    echo -e "${RED}Failed to compile $src_file${NC}"
    log "FAILED: $src_file"
  fi
}

[ -f $LOG_FILE ] && rm $LOG_FILE

compile_in_parallel() {
  local src_files=("$@")
  local active_jobs=0

  for src_file in "${src_files[@]}"; do
    ((active_jobs >= MAX_JOBS)) && wait -n
    compile $src_file &
    ((active_jobs++))
  done

  wait
}

src_files=()
for src_file in *.c; do
  [ -e "$src_file" ] && src_files+=("$src_file")
done

compile_in_parallel "${src_files[@]}"

echo -e "${GREEN}All modules compiled.${NC}\nLog saved to $LOG_FILE"