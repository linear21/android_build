#!/bin/bash
#
# Copyright (C) 2023 The Minerva's Dome.
#
# SPDX-License-Identifier: Apache-2.0
#

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
