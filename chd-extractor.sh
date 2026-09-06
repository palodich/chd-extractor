#!/usr/bin/env bash
#
# Bulk-extract CHD disc images using chdman.
#
# Usage: ./chd-extractor.sh -i <input_folder> [-o <output_folder>] [--extension .cue|.gdi|.iso]
#
# If -o is omitted, output goes to an "output" subfolder inside <input_folder>.
#
# For each .chd file directly inside <input_folder> (not recursive), extracts the
# disc image into <output_folder>. Multi-file formats (.cue+.bin, .gdi+
# tracks) get their own subfolder named after the CHD (without extension);
# single-file .iso output is written directly into <output_folder>.
#
# By default the disc type (and thus output format) is auto-detected per
# file via `chdman info`, using the CHD's metadata tag:
#   'DVD '            -> DVD-ROM  -> extractdvd -> <name>.iso
#   'CHGD'            -> GD-ROM   -> extractcd  -> <name>.gdi
#   anything else     -> CD-ROM   -> extractcd  -> <name>.cue + <name>.bin
#
# Pass --extension to force one format for every file instead of
# auto-detecting (e.g. if you know every CHD in the folder is the same type).
#
# chdman is looked up next to this script, falling back to PATH.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -x "$SCRIPT_DIR/chdman" ]; then
    CHDMAN="$SCRIPT_DIR/chdman"
else
    CHDMAN="chdman"
fi

usage() {
    echo "Usage: $0 -i <input_folder> [-o <output_folder>] [--extension .cue|.gdi|.iso]" >&2
    exit 1
}

INPUT_DIR=""
OUTPUT_DIR=""
FORCE_EXT=""

while [ $# -gt 0 ]; do
    case "$1" in
        -i|--input) INPUT_DIR="$2"; shift 2 ;;
        -o|--output) OUTPUT_DIR="$2"; shift 2 ;;
        --extension) FORCE_EXT="$2"; shift 2 ;;
        *) usage ;;
    esac
done

[ -n "$INPUT_DIR" ] || usage
[ -n "$OUTPUT_DIR" ] || OUTPUT_DIR="$INPUT_DIR/output"

case "$FORCE_EXT" in
    ""|.cue|.gdi|.iso) ;;
    *) echo "Error: --extension must be one of .cue, .gdi, .iso" >&2; exit 1 ;;
esac

[ -d "$INPUT_DIR" ] || { echo "Error: input folder '$INPUT_DIR' does not exist" >&2; exit 1; }
command -v "$CHDMAN" >/dev/null 2>&1 || { echo "Error: chdman not found next to this script or in PATH" >&2; exit 1; }

mkdir -p "$OUTPUT_DIR"

# Prints the extension to use for a given CHD (.cue, .gdi, or .iso),
# auto-detected from its chdman metadata tag unless FORCE_EXT is set.
detect_extension() {
    local chd_path="$1"

    if [ -n "$FORCE_EXT" ]; then
        echo "$FORCE_EXT"
        return
    fi

    local tag
    tag="$("$CHDMAN" info -i "$chd_path" 2>/dev/null | grep -m1 "^Metadata:" | sed -n "s/.*Tag='\([^']*\)'.*/\1/p")"

    case "$tag" in
        "DVD ") echo ".iso" ;;
        "CHGD") echo ".gdi" ;;
        *) echo ".cue" ;;
    esac
}

chd_files=()
while IFS= read -r -d '' f; do
    chd_files+=("$f")
done < <(find "$INPUT_DIR" -maxdepth 1 -iname '*.chd' -type f -print0)

if [ ${#chd_files[@]} -eq 0 ]; then
    echo "No .chd files found in '$INPUT_DIR'"
    exit 0
fi

total=${#chd_files[@]}
count=0
failed=()

for chd_path in "${chd_files[@]}"; do
    count=$((count + 1))
    name="$(basename "$chd_path")"
    name="${name%.*}"

    ext="$(detect_extension "$chd_path")"

    if [ "$ext" = ".iso" ]; then
        dest_dir="$OUTPUT_DIR"
    else
        dest_dir="$OUTPUT_DIR/$name"
    fi
    toc_path="$dest_dir/$name$ext"

    echo "[$count/$total] $name ($ext)"

    if [ -f "$toc_path" ]; then
        echo "  -> already extracted, skipping"
        continue
    fi

    mkdir -p "$dest_dir"

    extract_ok=1
    case "$ext" in
        .iso)
            "$CHDMAN" extractdvd -i "$chd_path" -o "$toc_path" -f >/dev/null || extract_ok=0
            ;;
        .gdi)
            "$CHDMAN" extractcd -i "$chd_path" -o "$toc_path" -f >/dev/null || extract_ok=0
            ;;
        .cue)
            bin_path="$dest_dir/$name.bin"
            "$CHDMAN" extractcd -i "$chd_path" -o "$toc_path" -ob "$bin_path" -f >/dev/null || extract_ok=0
            ;;
    esac

    if [ "$extract_ok" -eq 1 ]; then
        echo "  -> extracted to $toc_path"
    else
        echo "  -> FAILED"
        failed+=("$chd_path")
        if [ "$ext" = ".iso" ]; then
            rm -f "$toc_path"
        else
            rm -rf "$dest_dir"
        fi
    fi
done

echo
echo "Done: $((total - ${#failed[@]}))/$total extracted successfully."

if [ ${#failed[@]} -gt 0 ]; then
    echo "Failed:"
    printf '  %s\n' "${failed[@]}"
    exit 1
fi
