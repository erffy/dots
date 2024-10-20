#!/usr/bin/env bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

OUT_DIR="."
LOG_FILE="compile.log"
MAX_JOBS=$(nproc)

log_success() {
  echo "$1 at $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
}

log_failure() {
  echo "$1 at $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
}

command -v gcc &>/dev/null || { echo -e "${RED}Error: gcc is not installed.${NC}"; exit 1; }

while [[ "$1" != "" ]]; do
  case "$1" in
    --help)
      echo "Usage: $0 [--out-dir DIR] [--jobs N]"
      echo "Compile all .c files in the current directory (or DIR)."
      echo "Options:"
      echo "  --out-dir DIR    Set the output directory (default: current directory)"
      echo "  --jobs N         Set the number of parallel jobs (default: system CPU count)"
      exit 0
      ;;
    --out-dir)
      shift
      OUT_DIR="$1"
      ;;
    --jobs)
      shift
      MAX_JOBS="$1"
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      exit 1
      ;;
  esac
  shift
done

[[ $OUT_DIR != "." ]] && mkdir -p "$OUT_DIR"

[ -f "$LOG_FILE" ] && rm "$LOG_FILE"

compile() {
  local src_file="$1"
  local output_file="$OUT_DIR/$(basename "${src_file%.c}")"

  if [[ -f "$output_file" && "$output_file" -nt "$src_file" ]]; then
    echo -e "${YELLOW}Skipping $src_file (already up-to-date).${NC}"
    return 0
  fi

  echo -e "${YELLOW}Compiling $src_file...${NC}"

  start_time=$(date +%s)
  if gcc -o "$output_file" "$src_file"; then
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    echo -e "${GREEN}$src_file compiled successfully in $duration seconds.${NC}"
    log_success "SUCCESS: $src_file"
  else
    echo -e "${RED}Failed to compile $src_file${NC}"
    log_failure "FAILED: $src_file"
    return 1
  fi
}

compile_in_parallel() {
  local src_files=("$@")
  local job_count=0

  for src_file in "${src_files[@]}"; do
    compile "$src_file" &
    ((job_count++))

    if ((job_count >= MAX_JOBS)); then
      wait -n
      ((job_count--))
    fi
  done

  wait
}

src_files=(*.c)

if [ "${#src_files[@]}" -eq 0 ]; then
  echo -e "${RED}No .c files found in the current directory.${NC}"
  exit 1
fi

compile_in_parallel "${src_files[@]}"

echo -e "${GREEN}All modules compiled.${NC}\nLog saved to $LOG_FILE"

exit 0