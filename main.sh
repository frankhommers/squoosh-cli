#!/bin/bash
set -euo pipefail

# Compress a single image with squoosh-cli in Docker.
# Usage:
#   bash main.sh path/to/image.jpg           # Save with an _squoosh suffix
#   bash main.sh path/to/image.jpg --force   # Overwrite the original file
#   echo "path/to/image.jpg" | bash main.sh  # Read path from stdin
#
# Supported formats: jpg, jpeg, png
# Compression presets: JPG=mozjpeg(quality:30), PNG=oxipng(quality:30)

IMAGE_NAME="${IMAGE_NAME:-ghcr.io/frankhommers/squoosh-cli:latest}"

# Check whether stdin is piped in.
if [ -p /dev/stdin ]; then
    input=$(cat)
    force_update_option=${1-}
else
    input=${1-}
    force_update_option=${2-}
fi


# Prepare the working directory.
# You can override it with the WORKDIR environment variable.
function check_workdir() {
  if [ -z "${WORKDIR:-}" ]; then
    WORKDIR=/tmp/squoosh
  fi

  if [ ! -d "$WORKDIR" ]; then
    mkdir -p "$WORKDIR"
  fi
}

# Validate the input file and supported options.
function validate(){
  local input=$1
  local force_update_option=$2
  local arg_count=$3

  if [ -z "$input" ]; then
    echo "Error: please provide a file path."
    exit 1
  fi

  if [ ! -e "$input" ]; then
    echo "Error: the specified file does not exist."
    exit 1
  fi

  if [ "$arg_count" -eq 2 ]; then
    if [ "$force_update_option" != "-f" ] && [ "$force_update_option" != "--force" ]; then
      echo "Error: the second argument must be '-f' or '--force'."
      exit 1
    fi
  fi
}

# Copy the source file into the working directory.
function copy_to_workdir()
{
  local dirname="$1"
  local filename="$2"
  WORK_FILE_PATH="$WORKDIR/$filename"
  cp "$dirname/$filename" "$WORK_FILE_PATH"
}

# Run squoosh-cli inside Docker.
function optimize()
{
  local filename="$1"
  local ext="$2"

  if [ "$ext" = "jpg" ] || [ "$ext" = "jpeg" ]; then
    docker run --rm -v "$WORKDIR:/work" "$IMAGE_NAME" --mozjpeg '{quality:30}' -d /work "/work/$filename"
  elif [ "$ext" = "png" ]; then
    docker run --rm -v "$WORKDIR:/work" "$IMAGE_NAME" --oxipng '{quality:30}' -d /work "/work/$filename"
  else
    echo "Error: only jpg, jpeg, and png files are supported."
    exit 1
  fi
}

# Move the optimized file back next to the original.
function move_to_originaldir()
{
  dirname="$1"
  basename="$2"
  ext="$3"
  force_update="$4"
  optimized_file=""

  if [ "$ext" = "jpeg" ]; then
    if [ -f "$WORKDIR/${basename}.jpg" ]; then
      optimized_file="$WORKDIR/${basename}.jpg"
    elif [ -f "$WORKDIR/${basename}.jpeg" ]; then
      optimized_file="$WORKDIR/${basename}.jpeg"
    fi
  else
    optimized_file="$WORKDIR/${basename}.${ext}"
  fi

  if [ ! -f "$optimized_file" ]; then
    echo "Error: optimized file not found: $optimized_file"
    exit 1
  fi

  message="update "
  if [ "$force_update" = false ]; then
    basename="${basename}_squoosh"
    message="create "
  fi
  copy_file_path="$dirname/${basename}.${ext}"
  echo "${message} $copy_file_path"
  mv -f "$optimized_file" "$copy_file_path"
}

# Main flow.
validate "$input" "$force_update_option" "$#"
check_workdir

dirname=$(cd "$(dirname "$input")"; pwd)
filename=$(basename "$input")
basename=${filename%.*}
ext=$(echo ${filename##*.} | tr '[A-Z]' '[a-z]')


force_update=false
if [ $# -eq 2 ]; then
  if [ "$force_update_option" = "-f" ] || [ "$force_update_option" = "--force" ]; then
    force_update=true
  fi
fi

copy_to_workdir "$dirname" "$filename"
optimize "$filename" "$ext"
move_to_originaldir "$dirname" "$basename" "$ext" "$force_update"
