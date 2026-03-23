# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`squoosh-cli-on-docker` makes the Google Chrome team's `squoosh-cli` available through Docker. It provides a command-line interface for image optimization without requiring a local Node setup that matches the older working runtime.

## Architecture

### Core Components

- **main.sh**: Main shell script. Supports both stdin and direct file-path arguments and manages single-image compression.
- **squoosh.sh**: Thin Docker wrapper that forwards arbitrary CLI arguments to the containerized `squoosh-cli`.
- **Dockerfile**: Node.js 14.19.0-based container with global `@squoosh/cli` installation.
- **sample/**: Sample images for quick verification.

### Processing Flow

1. Validate the input file and optional flags.
2. Prepare a working directory (default: `/tmp/squoosh`).
3. Copy the input file into the working directory.
4. Run Dockerized compression based on file extension.
   - JPG: `mozjpeg` with `quality:30`
   - PNG: `oxipng` with `quality:30`
5. Move the optimized file back to the original directory.

### Input Handling

- Supports stdin path input.
- Supports direct file-path arguments.
- Supports `--force`/`-f` to overwrite the source file; otherwise creates an `_squoosh` copy.

## Development Commands

### Build
```bash
docker build -t ghcr.io/frankhommers/squoosh-cli:{version} .
```

### Run
```bash
# Direct Docker usage
docker run --rm -v "$(pwd)":/work -w /work ghcr.io/frankhommers/squoosh-cli:latest --mozjpeg '{"quality":30}' -d /work sample/sample1.jpg

# Through shell wrappers
bash main.sh sample/sample1.jpg
bash main.sh sample/sample1.jpg --force
./squoosh.sh --help
```

### Test
```bash
# Smoke tests with sample images
bash main.sh sample/sample1.jpg
bash main.sh sample/sample2.png
```

## Important Constraints

- Only jpg/jpeg/png flows are implemented in the helper scripts.
- Docker is required.
- A temporary working directory is required and can be overridden with `WORKDIR`.
- File extension matching is case-insensitive.
