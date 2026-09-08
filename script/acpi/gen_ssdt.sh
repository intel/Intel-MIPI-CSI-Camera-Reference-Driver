#!/bin/bash
#
# Copyright (C) 2026 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

shopt -s nullglob

IASL_VERSION="$(iasl -v 2>&1 | grep -oE '[0-9]{8}' | head -n1)"
if [ -z "$IASL_VERSION" ]; then
    echo "ERROR: unable to determine iasl version" >&2
    exit 1
fi

if [ "$IASL_VERSION" -lt 20260408 ]; then
    echo "ERROR: iasl version $IASL_VERSION is too old; need 20260408 or newer" >&2
    exit 1
fi

if ! grep -qF 'GRUB_EARLY_INITRD_LINUX_CUSTOM="img_ssdt.img"' /etc/default/grub; then
    echo 'ERROR: /etc/default/grub must contain GRUB_EARLY_INITRD_LINUX_CUSTOM="img_ssdt.img"' >&2
    exit 1
fi

FW_BASE_DIR="/tmp"
DIR="kernel/firmware/acpi"
SSDT_IMG="$FW_BASE_DIR/img_ssdt.img"

if [ -z "$1" ]; then
    echo "Usage: $0 <asl file>"
    exit 1
fi

# Derive the AML path next to the input ASL (iasl writes the AML in the
# same directory as the input file, not in $PWD).
AML="${1%.asl}.aml"

# Remove any stale outputs from a previous run so a failed recompile
# cannot leave the old AML in place to be packaged below.
rm -f "$AML" "$SSDT_IMG"

iasl -li "$1"
ASL_DIR="$PWD"

# iasl can return 0 with warnings but skip writing the AML on errors;
# guard against that as well.
if [ ! -f "$AML" ]; then
    echo "ERROR: iasl did not produce '$AML'" >&2
    exit 1
fi

cd "$FW_BASE_DIR"
mkdir -p "$DIR"
rm -f "$DIR"/*
cp "$ASL_DIR"/"$AML" "$FW_BASE_DIR"/"$DIR"
find kernel | cpio -H newc --create > "$SSDT_IMG"

if [ -f "$SSDT_IMG" ]; then
    echo "Successful generation of $SSDT_IMG"
else
    echo "ERROR: failed to generate $SSDT_IMG" >&2
    exit 1
fi

if sudo cp "$SSDT_IMG" /boot; then
    echo "Successful copy of $SSDT_IMG to /boot"
else
    echo "ERROR: failed to copy $SSDT_IMG to /boot" >&2
    exit 1
fi
