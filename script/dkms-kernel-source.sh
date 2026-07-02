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

# Git tag matching this release, e.g. v6.17 or v6.17.1 (used by GitHub archives).
if (( patch != 0 )); then
  gittag="v$major.$minor.$patch"
else
  gittag="v$major.$minor"
fi

# Sources to try, in order. The kernel.org CDN only keeps the .tar.xz base
# tarballs for currently-maintained series; once a series (e.g. 6.17) reaches
# EOL its base tarball is removed and returns 404. The GitHub archive and
# git.kernel.org snapshot endpoints regenerate a .tar.gz for *any* tag on
# demand, so they are used as fallbacks that always work for released versions.
mirrors=(
    "https://github.com/torvalds/linux/archive/refs/tags/${gittag}.tar.gz"
    "https://cdn.kernel.org/pub/linux/kernel/v${major}.x/${tarball}"
    "https://mirrors.edge.kernel.org/pub/linux/kernel/v${major}.x/${tarball}"
    "https://www.kernel.org/pub/linux/kernel/v${major}.x/${tarball}"
    "https://mirrors.kernel.org/pub/linux/kernel/v${major}.x/${tarball}"
    "https://mirror.math.princeton.edu/pub/kernel/linux/kernel/v${major}.x/${tarball}"
    "https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/snapshot/${kernelprefix}.tar.gz"
    "https://git.kernel.org/torvalds/t/${kernelprefix}.tar.gz"
)

# Return the local filename to use for a given URL (preserves .tar.gz vs .tar.xz).
local_name_for() {
    case "$1" in
        *.tar.gz) echo "${kernelprefix}.tar.gz" ;;
        *)        echo "${kernelprefix}.tar.xz" ;;
    esac
}

# Verify an archive's integrity based on its compression format.
verify_archive() {
    case "$1" in
        *.tar.gz) gzip -t "$1" 2>/dev/null ;;
        *)        xz -t "$1" 2>/dev/null ;;
    esac
}

archive=""

# Reuse a previously downloaded, still-valid tarball if the remote size matches.
for candidate in "${kernelprefix}.tar.xz" "${kernelprefix}.tar.gz"; do
    [[ -s "$candidate" ]] && verify_archive "$candidate" || continue
    local_size=$(stat -c %s "$candidate")
    for url in "${mirrors[@]}"; do
        [[ "$(local_name_for "$url")" == "$candidate" ]] || continue
        remote_size=$(curl -fsSLI "$url" 2>/dev/null \
            | awk 'BEGIN{IGNORECASE=1} /^content-length:/ {gsub("\r",""); print $2}' \
            | tail -1)
        if [[ -n "$remote_size" && "$local_size" == "$remote_size" ]]; then
            echo "dkms-kernel-source.sh: reusing cached ${candidate} (${local_size} bytes)"
            archive="$candidate"
            break 2
        fi
    done
done

if [[ -z "$archive" ]]; then
    for url in "${mirrors[@]}"; do
        out="$(local_name_for "$url")"
        echo "Downloading $url"
        if wget --no-check-certificate -q --show-progress "$url" -O "$out"; then
            if [[ -s "$out" ]] && verify_archive "$out"; then
                archive="$out"
                break
            fi
            echo "dkms-kernel-source.sh: ${url} returned an invalid archive, trying next mirror" >&2
        else
            echo "dkms-kernel-source.sh: failed to download ${url}, trying next mirror" >&2
        fi
        rm -f "$out"
    done
    if [[ -z "$archive" ]]; then
        echo "dkms-kernel-source.sh: all mirrors failed for ${kernelprefix}" >&2
        return 1
    fi
fi

for arg in "$@"; do
    echo "Extracting: $kernelprefix/$arg"
    tar -xvf "$archive" "$kernelprefix/$arg" \
      --xform="s,^${kernelprefix//./\\.}/,$major.$minor.0/,"
done
