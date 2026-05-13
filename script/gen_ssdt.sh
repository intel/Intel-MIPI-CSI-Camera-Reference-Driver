#!/bin/bash
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
