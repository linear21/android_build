#!/bin/bash
#
# Copyright (C) 2023 The Minerva's Dome.
#
# SPDX-License-Identifier: Apache-2.0
#

# Start building.
$LUNCH_TARGET
$MAKE_TARGET

# Upload finished build.
BUILD_FILENAME="$(ls out/target/product/$(grep unch main.sh -m 1 | cut -d ' ' -f 2 | cut -d _ -f 2 | cut -d - -f 1)/recovery.img $(ls out/target/product/$(grep unch main.sh -m 1 | cut -d ' ' -f 2 | cut -d _ -f 2 | cut -d - -f 1)/*.zip))"
rclone copy $BUILD_FILENAME $RCLONE_NAME:$RCLONE_FOLDER -P

# Upload recovery image build.
cp out/target/product/$(grep unch main.sh -m 1 | cut -d ' ' -f 2 | cut -d _ -f 2 | cut -d - -f 1)/recovery.img $(basename $BUILD_FILENAME .zip).img
rclone copy $(basename $BUILD_FILENAME .zip).img $RCLONE_NAME:$RCLONE_FOLDER -P
