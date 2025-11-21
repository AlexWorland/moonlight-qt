# Building Moonlight Qt Locally

This guide covers how to set up and build Moonlight Qt on your local machine.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Initial Setup](#initial-setup)
- [Build Methods](#build-methods)
  - [Docker Build (Recommended)](#docker-build-recommended)
  - [Native Build](#native-build)
- [Platform-Specific Instructions](#platform-specific-instructions)
- [Build Scripts](#build-scripts)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### All Platforms

- Git
- CMake (for some dependencies)
- A C++ compiler (GCC, Clang, or MSVC)

### Windows

- **Qt 6.7 SDK or later** - Download from [qt.io](https://www.qt.io/download)
  - Select **MSVC** option during installation (MinGW is not supported)
- **Visual Studio 2022** - [Download](https://visualstudio.microsoft.com/downloads/) (Community edition is fine)
- **7-Zip** - [Download](https://www.7-zip.org/) (only if building installers)
- **Graphics Tools** (for debug builds):
  - Install "Graphics Tools" in Windows Settings > Optional Features
  - Or run: `dism /online /add-capability /capabilityname:Tools.Graphics.DirectX~~~~0.0.1.0` and reboot

### macOS

- **Qt 6.7 SDK or later** - Download from [qt.io](https://www.qt.io/download) or install via Homebrew:
  ```bash
  brew install qt --with-debug  # For debug builds
  ```
- **Xcode 14 or later** - Available from Mac App Store
- **create-dmg** (for DMG creation):
  ```bash
  npm install --global create-dmg
  ```

### Linux

- **Qt 6** (recommended) or Qt 5.12+
- **GCC or Clang**
- **FFmpeg 4.0+**
- **System packages** (see below for distro-specific instructions)

#### Debian/Ubuntu

```bash
# Base requirements
sudo apt-get install -y \
  libegl1-mesa-dev libgl1-mesa-dev libopus-dev libsdl2-dev libsdl2-ttf-dev \
  libssl-dev libavcodec-dev libavformat-dev libswscale-dev libva-dev \
  libvdpau-dev libxkbcommon-dev wayland-protocols libdrm-dev

# Qt 6 (Recommended)
sudo apt-get install -y \
  qt6-base-dev qt6-declarative-dev libqt6svg6-dev \
  qml6-module-qtquick-controls qml6-module-qtquick-templates \
  qml6-module-qtquick-layouts qml6-module-qtqml-workerscript \
  qml6-module-qtquick-window qml6-module-qtquick

# Qt 5 (Alternative)
sudo apt-get install -y \
  qtbase5-dev qt5-qmake qtdeclarative5-dev qtquickcontrols2-5-dev \
  qml-module-qtquick-controls2 qml-module-qtquick-layouts \
  qml-module-qtquick-window2 qml-module-qtquick2 qtwayland5
```

#### Fedora/RHEL (RPM Fusion repo required)

```bash
# Base requirements
sudo dnf install -y \
  openssl-devel SDL2-devel SDL2_ttf-devel ffmpeg-devel libva-devel \
  libvdpau-devel opus-devel pulseaudio-libs-devel alsa-lib-devel libdrm-devel

# Qt 6 (Recommended)
sudo dnf install -y qt6-qtsvg-devel qt6-qtdeclarative-devel

# Qt 5 (Alternative)
sudo dnf install -y qt5-qtsvg-devel qt5-qtquickcontrols2-devel
```

**Note**: For Vulkan renderer support, you need `libplacebo-dev`/`libplacebo-devel` v7.349.0+ and FFmpeg 6.1+.

## Initial Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/moonlight-stream/moonlight-qt.git
   cd moonlight-qt
   ```

2. **Initialize submodules:**
   ```bash
   git submodule update --init --recursive
   ```

3. **Choose your build method** (see below)

## Build Methods

### Docker Build (Recommended)

Docker provides a consistent build environment and handles all dependencies automatically.

#### Prerequisites

- Docker or Docker Compose installed
- See [docker/README.md](docker/README.md) for detailed Docker instructions

#### Quick Start

**Development build (quick, no dependencies):**
```bash
docker-compose run --rm build-dev
```

**Full AppImage build (includes all dependencies):**
```bash
docker-compose run --rm build-appimage
```

**Interactive shell:**
```bash
docker-compose run --rm builder bash
```

#### Custom Version

Set a custom version for the build:
```bash
CI_VERSION=my-version docker-compose run --rm build-appimage
```

### Native Build

#### Linux Development Build

1. **Configure the project:**
   ```bash
   mkdir -p build/build-release
   cd build/build-release
   qmake6 ../../moonlight-qt.pro
   # Or for Qt 5: qmake ../../moonlight-qt.pro
   ```

2. **Build:**
   ```bash
   make -j$(nproc) release
   # Or for debug: make -j$(nproc) debug
   ```

3. **Run:**
   ```bash
   ./app/moonlight
   ```

#### Linux AppImage Build

Use the build script which handles dependencies:
```bash
scripts/build-appimage.sh
```

The AppImage will be in `build/installer-release/`.

#### Windows Build

1. **Open Qt Command Prompt** (from Start Menu)

2. **Navigate to project directory:**
   ```cmd
   cd path\to\moonlight-qt
   ```

3. **Build x64:**
   ```cmd
   scripts\build-arch.bat Release x64
   ```

4. **Build ARM64 (optional):**
   ```cmd
   scripts\build-arch.bat Release arm64
   ```

5. **Create installer bundle:**
   ```cmd
   scripts\generate-bundle.bat Release
   ```

Binaries will be in `build/deploy-x64-release/` and `build/deploy-arm64-release/`.

#### macOS Build

1. **Ensure Qt is in PATH:**
   ```bash
   export PATH="/path/to/Qt/6.x.x/macos/bin:$PATH"
   ```

2. **Build:**
   ```bash
   mkdir -p build/build-release
   cd build/build-release
   qmake6 ../../moonlight-qt.pro
   make -j$(sysctl -n hw.ncpu) release
   ```

3. **Create DMG (optional):**
   ```bash
   scripts/generate-dmg.sh Release
   ```

The DMG will be in `build/installer-Release/`.

## Platform-Specific Instructions

### Embedded Builds

For single-purpose devices (Raspberry Pi, etc.):

```bash
qmake6 "CONFIG+=embedded" moonlight-qt.pro
make release
```

This removes windowed mode, Discord links, and other desktop-only features.

**For slow GPUs**, add `CONFIG+=gpuslow`:
```bash
qmake6 "CONFIG+=embedded CONFIG+=gpuslow" moonlight-qt.pro
```

This prefers direct KMSDRM rendering over GL/Vulkan.

### Steam Link Builds

1. **Clone Steam Link SDK:**
   ```bash
   git clone https://github.com/ValveSoftware/steamlink-sdk.git
   ```

2. **Set environment variable:**
   ```bash
   export STEAMLINK_SDK_PATH=/path/to/steamlink-sdk
   ```

3. **Build:**
   ```bash
   scripts/build-steamlink-app.sh
   ```

**Steam Link Limitations:**
- Maximum resolution: 1080p
- Maximum framerate: 60 FPS
- Maximum bitrate: 40 Mbps
- HDR not supported on original hardware

## Build Scripts

All build scripts are in the `scripts/` directory:

- **`build-appimage.sh`** - Linux AppImage build
- **`build-steamlink-app.sh`** - Steam Link build
- **`build-arch.bat`** - Windows x64/ARM64 build
- **`generate-bundle.bat`** - Windows installer creation
- **`generate-dmg.sh`** - macOS DMG creation

## Troubleshooting

### Qt Not Found

**Linux:**
```bash
# Find qmake6
which qmake6

# If not found, ensure Qt is installed and in PATH
export PATH="/usr/lib/qt6/bin:$PATH"
```

**macOS:**
```bash
# If installed via Homebrew
export PATH="/opt/homebrew/opt/qt@6/bin:$PATH"

# If installed from qt.io
export PATH="/path/to/Qt/6.x.x/macos/bin:$PATH"
```

**Windows:**
- Use the "Qt Command Prompt" from Start Menu
- Or manually add Qt bin directory to PATH

### Submodule Issues

If submodules fail to initialize:
```bash
git submodule update --init --recursive --force
```

### Permission Issues (Docker)

If Docker builds create files with wrong permissions:
```bash
# Fix ownership
sudo chown -R $USER:$USER build/ deps/
```

### Build Failures

1. **Clean build:**
   ```bash
   rm -rf build/
   # Rebuild from scratch
   ```

2. **Check dependencies:**
   ```bash
   # Linux - verify packages installed
   dpkg -l | grep qt6  # Debian/Ubuntu
   rpm -qa | grep qt6  # Fedora/RHEL
   ```

3. **Check compiler:**
   ```bash
   gcc --version  # or clang --version
   ```

### FFmpeg Issues

If FFmpeg is not found or wrong version:
```bash
# Check version
ffmpeg -version

# Linux - install/update
sudo apt-get install libavcodec-dev libavformat-dev libswscale-dev  # Debian/Ubuntu
sudo dnf install ffmpeg-devel  # Fedora/RHEL
```

### Windows-Specific Issues

**MSVC Not Found:**
- Ensure Visual Studio 2022 is installed with C++ workload
- Use "Developer Command Prompt for VS 2022"

**7-Zip Not Found:**
- Install 7-Zip and add to PATH
- Or set `PATH` to include 7-Zip bin directory

**Graphics Tools Missing (Debug builds):**
- Install via Windows Settings > Optional Features
- Or run: `dism /online /add-capability /capabilityname:Tools.Graphics.DirectX~~~~0.0.1.0`

### macOS-Specific Issues

**Code Signing:**
- For distribution, you may need to code sign the app
- See Apple Developer documentation for details

**Homebrew Qt Issues:**
- Use `brew install qt --with-debug` for debug builds
- Or download Qt from qt.io for more control

## Development Tips

### Debug Builds

```bash
# Linux/macOS
qmake6 moonlight-qt.pro
make debug

# Windows (in Qt Command Prompt)
qmake6 moonlight-qt.pro
nmake debug
```

### Incremental Builds

After initial build, only changed files are rebuilt:
```bash
make -j$(nproc)  # Linux
make -j$(sysctl -n hw.ncpu)  # macOS
nmake  # Windows
```

### Cleaning Builds

```bash
# Clean build directory
rm -rf build/

# Or from build directory
make clean  # Linux/macOS
nmake clean  # Windows
```

### Running Tests

Currently, there are no automated tests. Manual testing is required.

## Getting Help

- **Issues**: [GitHub Issues](https://github.com/moonlight-stream/moonlight-qt/issues)
- **Discord**: [Moonlight Discord](https://moonlight-stream.org/discord)
- **Documentation**: See [docs/](docs/) directory

## Next Steps

After building successfully:
- Test the application with your host PC
- Check [README.md](README.md) for usage instructions
- See [docs/](docs/) for feature documentation
