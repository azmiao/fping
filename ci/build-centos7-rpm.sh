#!/bin/bash
set -euo pipefail

# Run as root inside a CentOS 7 x86_64 container with NET_RAW and NET_ADMIN.
# shellcheck source=/dev/null
source /etc/os-release
if [[ "$ID" != centos || "$VERSION_ID" != 7 || "$(uname -m)" != x86_64 || "$EUID" != 0 ]]; then
    echo "This script requires a CentOS 7 x86_64 container running as root." >&2
    exit 1
fi

source_dir=$(cd "$(dirname "$0")/.." && pwd)
output_dir=${1:-/output}
mkdir -p "$output_dir"
output_dir=$(cd "$output_dir" && pwd)
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

# CentOS 7 is EOL; use signed packages from the final release archive.
mkdir -p "$work_dir/repos"
for repo in base updates extras; do
    repo_path=$repo
    if [[ "$repo" == base ]]; then
        repo_path=os
    fi
    cat > "$work_dir/repos/$repo.repo" <<EOF
[fping-$repo]
name=CentOS 7.9.2009 $repo
baseurl=https://vault.centos.org/7.9.2009/$repo_path/\$basearch/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
sslverify=1
EOF
done
yum --setopt="reposdir=$work_dir/repos" --setopt=skip_if_unavailable=false \
    -y install autoconf automake gcc make rpm-build redhat-rpm-config \
    perl libcap tar gzip

bash "$source_dir/ci/build-rpm.sh" "$output_dir" el7
