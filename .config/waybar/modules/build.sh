#!/usr/bin/env bash

# Color codes
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[0;33m'
declare -r NC='\033[0m'

,OUT_DIR="."
LOG_FILE="compile.log"
MAX_JOBS=$(nproc)
declare -A COMPILE_FLAGS_CACHE

init() {
    if ! command -v gcc >/dev/null; then
        printf "${RED}Error: gcc is not installed.${NC}\n" >&2
        exit 1
    fi

    [[ $OUT_DIR != "." ]] && mkdir -p "$OUT_DIR"
    
    : > "$LOG_FILE"
}

log() {
    local timestamp
    printf -v timestamp '%(%Y-%m-%d %H:%M:%S)T' -1
    printf '%s %s\n' "$1" "at $timestamp" >> "$LOG_FILE"
}

cache_compile_flags() {
    local file flags
    for file in "${!SRC_FILES[@]}"; do
        if [[ -f "$file" ]]; then
            read -r flags < <(grep -m1 -oP '^//\s+-l\S*' "$file" 2>/dev/null | sed 's|^//\s*||')
            COMPILE_FLAGS_CACHE["$file"]="$flags"
        fi
    done
}

compile() {
    local src_file="$1"
    local output_file="$OUT_DIR/${src_file%.c}"
    local extra_flags="${COMPILE_FLAGS_CACHE[$src_file]}"
    local start_time end_time duration

    if [[ -f "$output_file" ]] && [[ "$output_file" -nt "$src_file" ]]; then
        printf "${YELLOW}Skipping %s (up-to-date)${NC}\n" "$src_file"
        return 0
    fi

    printf "${YELLOW}Compiling %s with flags: %s...${NC}\n" "$src_file" "$extra_flags"

    start_time=$SECONDS
    if gcc -O2 -o "$output_file" "$src_file" $extra_flags; then
        duration=$((SECONDS - start_time))
        printf "${GREEN}%s compiled successfully in %d seconds${NC}\n" "$src_file" "$duration"
        log "SUCCESS: $src_file"
        return 0
    else
        printf "${RED}Failed to compile %s${NC}\n" "$src_file" >&2
        log "FAILED: $src_file"
        return 1
    fi
}

compile_parallel() {
    local -i active=0
    local sem_file
    sem_file=$(mktemp)
    
    for ((i=0; i<MAX_JOBS; i++)); do
        printf '%d\n' "$i"
    done > "$sem_file"
    
    for src_file in "${!SRC_FILES[@]}"; do
        read -r slot < "$sem_file"
        
        {
            compile "$src_file"
            printf '%d\n' "$slot" >> "$sem_file"
        } &
        
        ((active++))
    done
    
    wait
    rm -f "$sem_file"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help)
                cat << EOF
Usage: $0 [--out-dir DIR] [--jobs N]
Compile all .c files in the current directory (or DIR).
Options:
  --out-dir DIR    Set the output directory (default: current directory)
  --jobs N         Set the number of parallel jobs (default: system CPU count)
EOF
                exit 0
                ;;
            --out-dir)
                OUT_DIR="$2"
                shift 2
                ;;
            --jobs)
                MAX_JOBS="$2"
                shift 2
                ;;
            *)
                printf "${RED}Unknown option: %s${NC}\n" "$1" >&2
                exit 1
                ;;
        esac
    done
}

main() {
    parse_args "$@"
    
    init
    
    declare -A SRC_FILES
    while read -r -d $'\0' file; do
        SRC_FILES["$file"]=1
    done < <(find . -maxdepth 1 -name "*.c" -print0)
    
    if [[ ${#SRC_FILES[@]} -eq 0 ]]; then
        printf "${RED}No .c files found in the current directory.${NC}\n" >&2
        exit 1
    fi
    
    cache_compile_flags
    compile_parallel
    
    printf "${GREEN}All modules compiled.${NC}\nLog saved to %s\n" "$LOG_FILE"
}

main "$@"