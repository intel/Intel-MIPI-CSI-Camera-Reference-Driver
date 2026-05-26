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

tarball="${kernelprefix}.tar.xz"
url="https://mirrors.edge.kernel.org/pub/linux/kernel/v${major}.x/${tarball}"

need_dl=1
if [[ -s "$tarball" ]] && xz -t "$tarball" 2>/dev/null; then
    local_size=$(stat -c %s "$tarball")
    remote_size=$(curl -fsSLI "$url" 2>/dev/null \
        | awk 'BEGIN{IGNORECASE=1} /^content-length:/ {gsub("\r",""); print $2}' \
        | tail -1)
    if [[ -n "$remote_size" && "$local_size" == "$remote_size" ]]; then
        echo "dkms-kernel-source.sh: reusing cached ${tarball} (${local_size} bytes)"
        need_dl=0
    fi
fi

if (( need_dl )); then
    echo "Downloading $url"
    wget --no-check-certificate -q --show-progress -N "$url" -O "$tarball" || {
        echo "dkms-kernel-source.sh: failed to download ${url}" >&2
        return 1
    }
fi

for arg in "$@"; do
    echo "Extracting: $kernelprefix/$arg"
    tar -xvf "$kernelprefix.tar.xz" "$kernelprefix/$arg" \
      --xform="s,^${kernelprefix//./\\.}/,$major.$minor.0/,"
done
