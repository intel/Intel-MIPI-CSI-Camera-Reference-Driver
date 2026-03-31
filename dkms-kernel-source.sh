#!/bin/bash

if [[ -z "${kernelver:-}" ]]; then
  kernelver="$(uname -r)"
fi

major=$(echo "$kernelver" | cut -d- -f1| cut -d. -f1)
minor=$(echo "$kernelver" | cut -d- -f1| cut -d. -f2)
patch=$(echo "$kernelver" | cut -d- -f1| cut -d. -f3)

if ! [[ "$major" =~ ^[0-9]+$ ]]; then major=0; fi
if ! [[ "$minor" =~ ^[0-9]+$ ]]; then minor=0; fi
if ! [[ "$patch" =~ ^[0-9]+$ ]]; then patch=0; fi

echo "Downloading major $major minor $minor patch $patch"
if (( patch != 0 )); then
  kernelprefix="linux-$major.$minor.$patch"
else
  kernelprefix="linux-$major.$minor"
fi
wget --no-check-certificate https://mirrors.edge.kernel.org/pub/linux/kernel/v$major.x/$kernelprefix.tar.xz -O $kernelprefix.tar.xz

for arg in "$@"; do
    echo "Extracting: $kernelprefix/$arg"
    tar -xvf "$kernelprefix.tar.xz" "$kernelprefix/$arg" \
      --xform="s,^${kernelprefix//./\\.}/,$major.$minor.0/,"
done
