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
export USER="minerva"

# Set up build command.
export LUNCH_TARGET="lunch eleon_merlinx-userdebug"
export MAKE_TARGET="m bacon -j16"
### Edit above this line. ###

# Download previous ccache.
cd ~/
rclone copy $RCLONE_NAME:$RCLONE_FOLDER/ccache.tar.gz . -P
time tar xf ccache.tar.gz
rm -rf ccache.tar.gz

# Create Android rootdir folder.
mkdir ~/android
cd ~/android

### Edit below this line. ###
# Initialize local repository.
repo init --no-repo-verify --depth=1 -u https://github.com/EleonOS/android_manifest.git -b thirteen -g default,-mips,-darwin,-notdefault

# Initialize local manifest.
git clone --depth=1 https://github.com/linear21/local_manifests.git -b eleon .repo/local_manifests
### Edit above this line. ###

# Start sync local source.
repo sync -q -c --no-clone-bundle --no-tags --optimized-fetch --prune --force-sync -j$(nproc --all)

# [WORKAROUND]
# We may will get an fatal error on first sync, re-sync local source to fix broken sync.
repo sync -c --no-clone-bundle --no-tags --optimized-fetch --prune --force-sync -j$(nproc --all)

## Building funtion.
# Collect ccache.
function collect_ccache() {
    # Start collecting ccache.
    $MAKE_TARGET &
    sleep 90m
    kill %1

    # Compress ccache folder.
    sleep 1m
    cd ~/
    tar --use-compress-program="pigz -k -1 " -cf ccache.tar.gz .ccache

    # Upload compressed ccache.
    rclone copy ccache.tar.gz $RCLONE_NAME:$RCLONE_FOLDER -P
}

# Final build.
function final_build() {
    # Start building.
    $MAKE_TARGET

    # Upload finished build.
    wget https://raw.githubusercontent.com/Sushrut1101/GoFile-Upload/master/upload.sh
    bash upload.sh out/target/product/$(echo $LUNCH_TARGET | cut -d ' ' -f 2 | cut -d _ -f 2 | cut -d - -f 1)/*.zip

    # Upload recovery image build.
    bash upload.sh out/target/product/$(echo $LUNCH_TARGET | cut -d ' ' -f 2 | cut -d _ -f 2 | cut -d - -f 1)/recovery.img
}

# Prepare build environment.
. build/envsetup.sh
rm -rf hardware/google/pixel/kernel_headers

# Lunch a device target.
$LUNCH_TARGET
export SKIP_ABI_CHECKS=true

# Set up ccache.
export CCACHE_DIR=~/.ccache
export CCACHE_EXEC=$(which ccache)
export USE_CCACHE=1
export CCACHE_COMPRESS=1
ccache --max-size=20G
ccache -s

# Auto-select build method.
CCACHE_TOTALSIZE=$(ccache -s | awk '/Cache size \(GB\):/ {match($0, /\(([0-9]+\.[0-9]+) %\)/, cache); print cache[1]}')
CCACHE_HITSIZE=$(ccache -s | awk '/Primary storage:/ {getline; match($0, /\(([0-9]+\.[0-9]+) %\)/, hits); print hits[1]}')
if [[ "${CCACHE_TOTALSIZE%.*}" -eq "0" ]]; then
    collect_ccache;
else
    if [[ "${CCACHE_HITSIZE%.*}" -ge "65" ]]; then
        final_build;
    else
        collect_ccache;
    fi
fi
