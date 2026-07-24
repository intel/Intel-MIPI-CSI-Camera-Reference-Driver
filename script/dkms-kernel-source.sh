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
set -euo pipefail

if [[ -z "${kernelver:-}" ]]; then
  kernelver="$(uname -r)"
fi

major=$(echo "$kernelver" | cut -d- -f1| cut -d. -f1)
minor=$(echo "$kernelver" | cut -d- -f1| cut -d. -f2)
patch=$(echo "$kernelver" | cut -d- -f1| cut -d. -f3)

# Fail fast on an unparseable version rather than silently fetching linux-0.0*.
if ! [[ "$major" =~ ^[0-9]+$ ]] || (( major < 1 )); then
  echo "dkms-kernel-source.sh: could not parse kernel major version from '${kernelver}'" >&2
  exit 1
fi
if ! [[ "$minor" =~ ^[0-9]+$ ]]; then
  echo "dkms-kernel-source.sh: could not parse kernel minor version from '${kernelver}'" >&2
  exit 1
fi
# patch is optional (e.g. "6.17" has no third component); default to 0 if absent.
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
# demand, so they can be used as fallbacks that always work for released versions.
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

# Persistent cache directory so repeated DKMS builds (e.g. across kernel
# reinstalls) don't re-download the same multi-hundred-MB tarball.
cache_dir="/usr/src"

# Reuse a previously cached tarball from /usr/src/ if it's still valid; this
# skips the network entirely on subsequent builds.
for candidate in "${kernelprefix}.tar.xz" "${kernelprefix}.tar.gz"; do
    cached="${cache_dir}/${candidate}"
    [[ -s "$cached" ]] && verify_archive "$cached" || continue
    echo "dkms-kernel-source.sh: reusing cached ${cached}"
    cp "$cached" "$candidate"
    archive="$candidate"
    break
done

# Reuse a previously downloaded, still-valid tarball if the remote size matches.
if [[ -z "$archive" ]]; then
for candidate in "${kernelprefix}.tar.xz" "${kernelprefix}.tar.gz"; do
    [[ -s "$candidate" ]] && verify_archive "$candidate" || continue
    local_size=$(stat -c %s "$candidate")
    for url in "${mirrors[@]}"; do
        [[ "$(local_name_for "$url")" == "$candidate" ]] || continue
        remote_size=$(curl -fsSLI \
            --connect-timeout 15 --max-time 60 \
            --retry 2 --retry-delay 2 --retry-connrefused \
            "$url" 2>/dev/null \
            | awk 'BEGIN{IGNORECASE=1} /^content-length:/ {gsub("\r",""); print $2}' \
            | tail -1 || true)
        if [[ -n "$remote_size" && "$local_size" == "$remote_size" ]]; then
            echo "dkms-kernel-source.sh: reusing cached ${candidate} (${local_size} bytes)"
            archive="$candidate"
            break 2
        fi
    done
done
fi

if [[ -z "$archive" ]]; then
    for url in "${mirrors[@]}"; do
        out="$(local_name_for "$url")"
        echo "Downloading $url"
        # timeout gives a hard overall ceiling so a slow-but-alive mirror that
        # trickles bytes under the read-timeout can't stall the DKMS build;
        # wget's own connect/read timeouts and limited retries handle the
        # common connect/stall cases and exit 124 on timeout -> next mirror.
        if timeout 600 wget -q --show-progress \
            --connect-timeout=15 --read-timeout=120 \
            --tries=3 --waitretry=2 \
            "$url" -O "$out"; then
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
        exit 1
    fi
    # Populate the persistent cache (best-effort) so future builds skip the
    # download. Failure to write (e.g. read-only /usr/src) is non-fatal.
    if cp "$archive" "${cache_dir}/${archive}" 2>/dev/null; then
        echo "dkms-kernel-source.sh: cached ${archive} to ${cache_dir}/"
    fi
fi

# Cache the archive listing once. Decompressing a ~150MB xz kernel tarball is
# expensive (several seconds), and we consult the listing both to determine
# the top-level directory and to enumerate matching members for every arg.
mapfile -t archive_members < <(tar -tf "$archive" 2>/dev/null || true)
if [[ ${#archive_members[@]} -eq 0 ]]; then
    echo "dkms-kernel-source.sh: failed to list contents of ${archive}" >&2
    exit 1
fi

# The first entry gives us the top-level directory name.
IFS=/ read -r archive_root _ <<<"${archive_members[0]}"
if [[ -z "${archive_root:-}" ]]; then
    echo "dkms-kernel-source.sh: could not determine archive root directory from ${archive}" >&2
    exit 1
fi
for arg in "$@"; do
    prefix="$archive_root/$arg"
    echo "Extracting: $prefix"

    # Some archives do not contain explicit directory entries. When POST_ADD
    # passes a directory, expand members below that prefix. Avoid passing both
    # the directory entry and its children to tar, which can trigger false
    # "Not found in archive" errors on compressed one-pass reads.
    if ! members_output="$(
        printf '%s\n' "${archive_members[@]}" | awk -v p="$prefix" '
            {
                if (index($0, p "/") == 1 && $0 != p "/") {
                    print $0
                    found_descendants = 1
                } else if ($0 == p || $0 == p "/") {
                    exact = $0
                }
            }
            END {
                if (!found_descendants && exact != "") {
                    print exact
                }
            }
        '
    )"; then
        echo "dkms-kernel-source.sh: failed to enumerate archive members for '$prefix'" >&2
        exit 1
    fi

    members=()
    [[ -n "$members_output" ]] && mapfile -t members <<<"$members_output"

    if [[ ${#members[@]} -eq 0 ]]; then
        echo "dkms-kernel-source.sh: no archive members matched '$prefix'" >&2
        exit 1
    fi

    tar -xvf "$archive" \
       --xform="s,^${archive_root//./\\.}/,$major.$minor.0/," \
         -- \
       "${members[@]}"
done
