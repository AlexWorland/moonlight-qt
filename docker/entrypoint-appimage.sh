#!/bin/bash
set -e

# Build dependencies if they don't exist
if [ ! -d "deps/SDL" ]; then
    echo "Building dependencies..."
    
    mkdir -p deps dep_root/{bin,include,lib}
    export DEP_ROOT=$PWD/dep_root
    export PATH=$DEP_ROOT/bin:$PATH
    
    # Build SDL
    if [ ! -d "deps/SDL" ]; then
        echo "Building SDL..."
        git clone --depth 1 https://github.com/libsdl-org/SDL.git -b 235e4870af091ea7e3814ee2dbdb8e2ec627aaf0 deps/SDL
        cd deps/SDL
        ./autogen.sh
        ./configure
        make -j$(nproc)
        sudo make install
        cd ../..
    fi
    
    # Build SDL_ttf
    if [ ! -d "deps/SDL_ttf" ]; then
        echo "Building SDL_ttf..."
        git clone --depth 1 https://github.com/libsdl-org/SDL_ttf.git -b release-2.22.0 --recursive deps/SDL_ttf
        cd deps/SDL_ttf
        ./autogen.sh
        ./configure
        make -j$(nproc)
        sudo make install
        cd ../..
    fi
    
    # Build libva
    if [ ! -d "deps/libva" ]; then
        echo "Building libva..."
        git clone --depth 1 https://github.com/intel/libva.git -b 2.22.0 deps/libva
        cd deps/libva
        ./autogen.sh
        ./configure --enable-x11
        make -j$(nproc)
        sudo make install
        cd ../..
    fi
    
    # Build libplacebo
    if [ ! -d "deps/libplacebo" ]; then
        echo "Building libplacebo..."
        git clone --depth 1 https://github.com/haasn/libplacebo.git -b 63a3d64ac32eaaa56aa60b5000d43c02544c6508 --recursive deps/libplacebo
        cd deps/libplacebo
        if [ -f "../../app/deploy/linux/appimage/*.patch" ]; then
            git apply ../../app/deploy/linux/appimage/*.patch || true
        fi
        meson setup build -Dvulkan=enabled -Dopengl=disabled -Ddemos=false
        ninja -C build
        sudo ninja install -C build
        cd ../..
    fi
    
    # Build dav1d
    if [ ! -d "deps/dav1d" ]; then
        echo "Building dav1d..."
        DAV1D_VER=1.5.1
        git clone --branch $DAV1D_VER --depth 1 https://code.videolan.org/videolan/dav1d.git deps/dav1d
        cd deps/dav1d
        meson setup build -Ddefault_library=static -Dbuildtype=release -Denable_tools=false -Denable_tests=false
        ninja -C build
        sudo ninja install -C build
        cd ../..
    fi
    
    # Build FFmpeg
    if [ ! -d "deps/FFmpeg" ]; then
        echo "Building FFmpeg..."
        git clone --depth 1 https://github.com/FFmpeg/FFmpeg.git -b dd00a614e16a15db0b230dfe45790e913e593695 deps/FFmpeg
        cd deps/FFmpeg
        ./configure --enable-pic --disable-static --enable-shared --disable-all --disable-autodetect \
            --enable-avcodec --enable-avformat --enable-swscale \
            --enable-decoder=h264 --enable-decoder=hevc --enable-decoder=av1 \
            --enable-vaapi --enable-hwaccel=h264_vaapi --enable-hwaccel=hevc_vaapi --enable-hwaccel=av1_vaapi \
            --enable-vdpau --enable-hwaccel=h264_vdpau --enable-hwaccel=hevc_vdpau --enable-hwaccel=av1_vdpau \
            --enable-libdrm --enable-vulkan --enable-hwaccel=h264_vulkan --enable-hwaccel=hevc_vulkan --enable-hwaccel=av1_vulkan \
            --enable-libdav1d --enable-decoder=libdav1d
        make -j$(nproc)
        sudo make install
        cd ../..
    fi
    
    # Install linuxdeployqt
    if [ ! -f "dep_root/bin/linuxdeployqt" ]; then
        echo "Installing linuxdeployqt..."
        mkdir -p dep_root/bin
        wget -O dep_root/bin/linuxdeployqt \
            https://github.com/probonopd/linuxdeployqt/releases/download/continuous/linuxdeployqt-continuous-x86_64.AppImage
        chmod a+x dep_root/bin/linuxdeployqt
    fi
    
    sudo ldconfig
    echo "Dependencies built successfully!"
fi

# Execute the command passed to the container
exec "$@"
