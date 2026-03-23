#!/bin/bash
set -euo pipefail

# Batch-optimize large images in an Obsidian media folder.
# Usage:
#   bash obsidian_media.sh           # Save with an _squoosh suffix
#   bash obsidian_media.sh --force   # Overwrite original files
#
# Target: /Users/a_kobori/Library/Mobile Documents/iCloud~md~obsidian/Documents/my-vault/media
# Filter: jpg, jpeg, and png files larger than 1 MB
# Compression presets: JPG=mozjpeg(quality:30), PNG=oxipng(quality:30)

IMAGE_NAME="${IMAGE_NAME:-ghcr.io/frankhommers/squoosh-cli:latest}"

# Obsidian media directory path.
OBSIDIAN_MEDIA_DIR="/Users/a_kobori/Library/Mobile Documents/iCloud~md~obsidian/Documents/my-vault/media"

# Prepare the working directory.
function check_workdir() {
  if [ -z "${WORKDIR:-}" ]; then
    WORKDIR=/tmp/squoosh
  fi

  if [ ! -d "$WORKDIR" ]; then
    mkdir -p "$WORKDIR"
  fi
}

# Validate the optional force flag.
function validate_options(){
  local force_update_option=$1

  if [ $# -eq 1 ]; then
    if [ "$force_update_option" != "-f" ] && [ "$force_update_option" != "--force" ]; then
      echo "Error: only '-f' or '--force' is supported."
      exit 1
    fi
  fi
}

# Confirm the Obsidian media directory exists.
function check_obsidian_dir() {
  if [ ! -d "$OBSIDIAN_MEDIA_DIR" ]; then
    echo "Error: the Obsidian media directory does not exist: $OBSIDIAN_MEDIA_DIR"
    exit 1
  fi
}

# Find images larger than 1 MB.
function find_large_images() {
  find "$OBSIDIAN_MEDIA_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -size +1M
}

# Copy the original file into the working directory.
function copy_to_workdir()
{
  local file_path="$1"
  local filename=$(basename "$file_path")

  WORK_FILE_PATH="$WORKDIR/$filename"
  cp "$file_path" "$WORK_FILE_PATH"
}

# Run squoosh-cli in Docker based on the file extension.
function optimize()
{
  local filename="$1"
  local ext="$2"

  if [ "$ext" = "jpg" ] || [ "$ext" = "jpeg" ]; then
    docker run --rm -v "$WORKDIR:/work" "$IMAGE_NAME" --mozjpeg '{quality:30}' -d /work "/work/$filename"
  elif [ "$ext" = "png" ]; then
    docker run --rm -v "$WORKDIR:/work" "$IMAGE_NAME" --quant '{numColors:64}' --oxipng '{}' -d /work "/work/$filename"
  else
    echo "Error: only jpg, jpeg, and png files are supported."
    exit 1
  fi
}

# Move the optimized file back next to the original.
function move_to_originaldir()
{
  local original_file_path="$1"
  local dirname=$(dirname "$original_file_path")
  local filename=$(basename "$original_file_path")
  local basename=${filename%.*}
  local original_ext=$(echo ${filename##*.} | tr '[A-Z]' '[a-z]')
  local force_update="$2"

  local optimized_file=""
  if [ "$original_ext" = "jpeg" ]; then
    if [ -f "$WORKDIR/${basename}.jpg" ]; then
      optimized_file="$WORKDIR/${basename}.jpg"
    elif [ -f "$WORKDIR/${basename}.jpeg" ]; then
      optimized_file="$WORKDIR/${basename}.jpeg"
    fi
  else
    optimized_file="$WORKDIR/${basename}.${original_ext}"
  fi

  if [ ! -f "$optimized_file" ]; then
    echo "Error: optimized file not found: $optimized_file"
    return 1
  fi

  message="update "
  local target_ext="$original_ext"

  if [ "$force_update" = false ]; then
    basename="${basename}_squoosh"
    message="create "
  fi

  copy_file_path="$dirname/${basename}.${target_ext}"
  echo "${message} $copy_file_path"
  mv -f "$optimized_file" "$copy_file_path"
}

# Format a file size in a readable way.
function get_file_size() {
  local file_path="$1"

  if stat -f%z "$file_path" >/dev/null 2>&1; then
    stat -f%z "$file_path"
  else
    stat -c%s "$file_path"
  fi
}

function format_size() {
  local size_bytes=$1
  if [ $size_bytes -ge 1073741824 ]; then
    echo "$(( size_bytes / 1073741824 ))GB"
  elif [ $size_bytes -ge 1048576 ]; then
    echo "$(( size_bytes / 1048576 ))MB"
  elif [ $size_bytes -ge 1024 ]; then
    echo "$(( size_bytes / 1024 ))KB"
  else
    echo "${size_bytes}B"
  fi
}

# Process one matching file.
function process_file() {
  local file_path="$1"
  local force_update="$2"

  local filename=$(basename "$file_path")
  local basename=${filename%.*}
  local ext=$(echo ${filename##*.} | tr '[A-Z]' '[a-z]')
  local file_size=$(get_file_size "$file_path")
  local file_size_formatted=$(format_size $file_size)

  echo "Processing: $filename ($file_size_formatted)"

  copy_to_workdir "$file_path"
  optimize "$filename" "$ext"
  move_to_originaldir "$file_path" "$force_update"

  local optimized_file_path
  if [ "$force_update" = true ]; then
    optimized_file_path="$file_path"
  else
    local dirname=$(dirname "$file_path")
    optimized_file_path="$dirname/${basename}_squoosh.${ext}"
  fi

  if [ -f "$optimized_file_path" ]; then
    local new_size=$(get_file_size "$optimized_file_path")
    local new_size_formatted=$(format_size $new_size)
    local reduction_percent=$(( (file_size - new_size) * 100 / file_size ))
    echo "Done: $filename $file_size_formatted -> $new_size_formatted (${reduction_percent}% smaller)"
  fi

  echo ""
}

echo "Obsidian media image optimization script"
echo "Target directory: $OBSIDIAN_MEDIA_DIR"
echo "Filter: jpg, jpeg, and png files larger than 1 MB"
echo ""

force_update_option=${1-}

validate_options $force_update_option
check_obsidian_dir
check_workdir

force_update=false
if [ "$force_update_option" = "-f" ] || [ "$force_update_option" = "--force" ]; then
  force_update=true
  echo "Mode: overwrite original files"
else
  echo "Mode: create new files with an _squoosh suffix"
fi
echo ""

echo "Searching for images larger than 1 MB..."
large_images=$(find_large_images)

if [ -z "$large_images" ]; then
  echo "No matching image files were found."
  exit 0
fi

file_count=$(echo "$large_images" | wc -l)
echo "Matching files: $file_count"
echo ""

while IFS= read -r file_path; do
  process_file "$file_path" "$force_update"
done <<< "$large_images"

echo "All image optimizations completed."
