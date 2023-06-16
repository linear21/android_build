#!/bin/bash
#
# Copyright (C) 2023 The Minerva's Dome.
#
# SPDX-License-Identifier: Apache-2.0
#

# Collect ccache.
function collect_ccache() {
    # Start collecting ccache.
    $LUNCH_TARGET
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
    $LUNCH_TARGET
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
