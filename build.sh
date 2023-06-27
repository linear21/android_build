#!/bin/bash
#
# Copyright (C) 2023 The Minerva's Dome.
#
# SPDX-License-Identifier: Apache-2.0
#

### Edit below this line. ###
# Set up rclone vars.
export RCLONE_NAME="drive"
export RCLONE_FOLDER="ci-test"

# Set build user and host name.
export BUILD_USERNAME="minerva"
export BUILD_HOSTNAME="android-build"

# Set up build command.
export LUNCH_TARGET="lunch arrow_merlinx-user"
export MAKE_TARGET="m bacon"
### Edit above this line. ###

# Download previous ccache.
cd ~/
rclone copy $RCLONE_NAME:$RCLONE_FOLDER/ccache.tar.gz . -P
time tar xf ccache.tar.gz

# Set up ccache.
export CCACHE_DIR="$HOME/.ccache"
export CCACHE_EXEC="$(which ccache)"
export USE_CCACHE=1
export CCACHE_COMPRESS=1
ccache --max-size=20G

# Create Android rootdir folder.
mkdir ~/android
cd ~/android

### Edit below this line. ###
# Initialize local repository.
repo init --no-repo-verify --depth=1 -u https://github.com/ArrowOS/android_manifest.git -b arrow-13.1 -g default,-mips,-darwin,-notdefault

# Initialize local manifest.
git clone --depth=1 https://github.com/linear21/local_manifests.git -b arrow-13.1 .repo/local_manifests
### Edit above this line. ###

# Start sync local source.
repo sync -q -c --no-clone-bundle --no-tags --optimized-fetch --prune --force-sync -j$(nproc --all)

# [WORKAROUND]
# We may will get an fatal error on first sync, re-sync local source to fix broken sync.
repo sync -c --no-clone-bundle --no-tags --optimized-fetch --prune --force-sync -j$(nproc --all)

# Use all core for building.
if [[ $MAKE_TARGET != *"mka"* ]]; then
    export MAKE_TARGET="$MAKE_TARGET -j$(nproc --all)"
fi

## Building funtion.
# Collect ccache.
function collect_ccache() {
    # Start collecting ccache.
    $MAKE_TARGET &
    sleep 90m
    kill %1

    # Compress ccache folder.
    sleep 1m
    tar --use-compress-program="pigz -k -1 " -cf ccache.tar.gz ~/.ccache

    # Upload compressed ccache.
    rclone copy ccache.tar.gz $RCLONE_NAME:$RCLONE_FOLDER -P
}

# Final build.
function final_build() {
    # Start building.
    $MAKE_TARGET

    # Upload finished build.
    BUILD_FILENAME="$(ls out/target/product/$(echo $LUNCH_TARGET | cut -d ' ' -f 2 | cut -d _ -f 2 | cut -d - -f 1)/recovery.img $(ls out/target/product/$(grep unch main.sh -m 1 | cut -d ' ' -f 2 | cut -d _ -f 2 | cut -d - -f 1)/*.zip))"
    rclone copy $BUILD_FILENAME $RCLONE_NAME:$RCLONE_FOLDER -P

    # Upload recovery image build.
    cp out/target/product/$(echo $LUNCH_TARGET | cut -d ' ' -f 2 | cut -d _ -f 2 | cut -d - -f 1)/recovery.img $(basename $BUILD_FILENAME .zip).img
    rclone copy $(basename $BUILD_FILENAME .zip).img $RCLONE_NAME:$RCLONE_FOLDER -P
}

# Prepare build environment.
. build/envsetup.sh

# Lunch a device target.
$LUNCH_TARGET

# Auto-select build method.
CCACHE_TOTALSIZE="$(ccache -s | grep -i "cache size" | grep -Eo '[0-9.]+ %')"
CCACHE_HITSIZE="$(ccache -s | grep -i "hit" | grep -Eo '[0-9.]+%')"
if [ "${CCACHE_TOTALSIZE%.*}" -eq "0.00" ]; then
    collect_ccache;
else
    if [ "${CCACHE_HITSIZE%.*}" -ge "85" ]; then
        final_build;
    else
        collect_ccache;
    fi
fi
