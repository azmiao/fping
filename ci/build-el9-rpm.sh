#!/bin/bash
set -euo pipefail

# Run as root inside a Rocky Linux 9 x86_64 container with NET_RAW and NET_ADMIN.
# shellcheck source=/dev/null
source /etc/os-release
if [[ "$ID" != rocky || "${VERSION_ID%%.*}" != 9 || "$(uname -m)" != x86_64 || "$EUID" != 0 ]]; then
    echo "This script requires a Rocky Linux 9 x86_64 container running as root." >&2
    exit 1
fi

source_dir=$(cd "$(dirname "$0")/.." && pwd)
dnf --setopt=skip_if_unavailable=false -y install \
    autoconf automake gcc make rpm-build redhat-rpm-config \
    perl libcap tar gzip util-linux

bash "$source_dir/ci/build-rpm.sh" "${1:-/output}" el9
