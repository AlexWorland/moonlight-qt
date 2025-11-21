# Docker Build Instructions

This directory contains Docker configurations for building Moonlight Qt locally.

## Prerequisites

- Docker or Docker Compose installed
- Git submodules initialized: `git submodule update --init --recursive`

## Quick Start

### Development Build (Quick)

Build a development binary without building all dependencies:

```bash
docker-compose run --rm build-dev
```

The binary will be in `build/build-release/app/moonlight`.

### AppImage Build (Full)

Build a complete AppImage with all dependencies:

```bash
docker-compose run --rm build-appimage
```

The AppImage will be in `build/installer-release/`.

### Interactive Shell

Get an interactive shell in the build environment:

```bash
docker-compose run --rm builder bash
```

Then you can run build commands manually:
```bash
git submodule update --init --recursive
scripts/build-appimage.sh
```

## Environment Variables

You can set environment variables to customize the build:

```bash
# Set version
CI_VERSION=test123 docker-compose run --rm build-appimage

# Set build config (release/debug)
BUILD_CONFIG=debug docker-compose run --rm build-dev
```

## Direct Docker Usage

If you prefer using Docker directly:

### Build the image:
```bash
docker build -t moonlight-qt-builder .
```

### Run a build:
```bash
docker run --rm -v $(pwd):/workspace -w /workspace moonlight-qt-builder scripts/build-appimage.sh
```

### Interactive shell:
```bash
docker run --rm -it -v $(pwd):/workspace -w /workspace moonlight-qt-builder bash
```

## Troubleshooting

### Permission Issues

If you encounter permission issues with build artifacts, you may need to adjust the user ID:

```bash
UID=$(id -u) GID=$(id -g) docker-compose run --rm build-dev
```

### Clean Build

To start fresh, remove build directories:

```bash
rm -rf build deps
```

### Rebuild Dependencies

The AppImage builder caches dependencies. To rebuild them:

```bash
rm -rf deps
docker-compose run --rm build-appimage
```

## Build Artifacts

- **Development builds**: `build/build-release/app/moonlight`
- **AppImage**: `build/installer-release/Moonlight-*.AppImage`
- **Dependencies**: Cached in `deps/` directory
