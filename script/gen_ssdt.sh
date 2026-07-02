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

set -ex
shopt -s nullglob

DIR="kernel/firmware/acpi"

if [ -z "$1" ]; then
    echo "Usage: $0 <asl file>"
    exit 1
fi

# Derive the AML path next to the input ASL (iasl writes the AML in the
# same directory as the input file, not in $PWD).
AML="${1%.asl}.aml"

# Remove any stale outputs from a previous run so a failed recompile
# cannot leave the old AML in place to be packaged below.
rm -f "$AML" ./img_ssdt.img

iasl -li "$1"

# iasl can return 0 with warnings but skip writing the AML on errors;
# guard against that as well.
if [ ! -f "$AML" ]; then
    echo "ERROR: iasl did not produce '$AML'" >&2
    exit 1
fi

mkdir -p "$DIR"
rm -f "$DIR"/*
cp "$AML" "$DIR"
find kernel | cpio -H newc --create > img_ssdt.img

sudo cp img_ssdt.img /boot
