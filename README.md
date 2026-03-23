# squoosh-cli on Docker

Run `@squoosh/cli` in Docker with a Node version that still works reliably for this package.

This fork keeps the image intentionally small, publishes it to GHCR, and adds shell wrappers for local use.

## Why this image exists

Recent Node releases break `@squoosh/cli` in common setups. This image pins `node:14.19.0`, installs `@squoosh/cli` globally, and exposes `squoosh-cli` as the container entrypoint.

## Pull the image

```bash
docker pull ghcr.io/frankhommers/squoosh-cli:latest
```

## Run it directly with Docker

```bash
docker run --rm -v "$(pwd)":/work -w /work ghcr.io/frankhommers/squoosh-cli:latest \
  --mozjpeg '{"quality":30}' \
  -d /work \
  sample/sample1.jpg
```

## Use the local wrapper script

The included `squoosh.sh` script forwards all arguments to the containerized CLI and mounts the current directory to `/work`.

```bash
./squoosh.sh --quant '{"enabled":true,"zx":0,"maxNumColors":256,"dither":0.5}' \
  --jxl '{"effort":9,"quality":75,"progressive":true,"epf":-1,"lossyPalette":false,"decodingSpeedTier":0,"photonNoiseIso":0,"lossyModular":false}' \
  frank.png
```

You can override the image name if needed:

```bash
IMAGE_NAME=ghcr.io/frankhommers/squoosh-cli:v1.0.0 ./squoosh.sh --help
```

## Install the wrapper with curl

User-local install:

```bash
mkdir -p ~/.local/bin
curl -fsSL https://raw.githubusercontent.com/frankhommers/squoosh-cli/main/squoosh.sh -o ~/.local/bin/squoosh
chmod +x ~/.local/bin/squoosh
```

System-wide install:

```bash
sudo curl -fsSL https://raw.githubusercontent.com/frankhommers/squoosh-cli/main/squoosh.sh -o /usr/local/bin/squoosh
sudo chmod +x /usr/local/bin/squoosh
```

Then run:

```bash
squoosh --help
```

## Convenience script for simple image optimization

`main.sh` wraps common presets for single-file optimization.

```bash
bash main.sh sample/sample1.jpg
bash main.sh sample/sample1.jpg --force
echo "sample/sample1.jpg" | bash main.sh
```

Supported formats:

- `jpg`
- `jpeg`
- `png`

Default presets:

- JPEG: `--mozjpeg '{quality:30}'`
- PNG: `--oxipng '{quality:30}'`

## Obsidian batch helper

`obsidian_media.sh` is an example batch script for optimizing large images in a specific Obsidian media folder. It keeps its machine-specific path and is best treated as a personal utility script you can adapt.

## Publishing

GitHub Actions publishes the container to GHCR:

- pushes to `main` update `ghcr.io/frankhommers/squoosh-cli:latest`
- tags like `v1.0.0` publish `ghcr.io/frankhommers/squoosh-cli:v1.0.0`
