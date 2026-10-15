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

# Build from a private copy, leaving the checked-out tree untouched.
mkdir -p "$work_dir/source" "$work_dir/rpmbuild"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
tar --exclude='./.git' --exclude='./artifacts' --exclude='./.openbitfun' \
    -C "$source_dir" -cf - . | tar -C "$work_dir/source" -xf -
cd "$work_dir/source"
bash ./autogen.sh
./configure --enable-ipv4 --enable-ipv6
make dist
version=$(sed -n 's/^PACKAGE_VERSION = //p' Makefile)
[[ "$version" =~ ^[0-9]+(\.[0-9]+)+$ ]]
release=${RPM_RELEASE:-1}
[[ "$release" =~ ^[0-9A-Za-z][0-9A-Za-z._]*$ ]]
cp "fping-$version.tar.gz" "$work_dir/rpmbuild/SOURCES/"
cp contrib/fping.spec "$work_dir/rpmbuild/SPECS/"
rpmbuild -ba "$work_dir/rpmbuild/SPECS/fping.spec" \
    --define "_topdir $work_dir/rpmbuild" \
    --define "fping_version $version" \
    --define "fping_release $release" \
    --define 'dist .el7'

# Exercise the installed RPM, not just the binary in the build tree.
packages=("$work_dir/rpmbuild/RPMS/x86_64/"fping-[0-9]*.x86_64.rpm)
[[ ${#packages[@]} == 1 && -f "${packages[0]}" ]]
rpm -Uvh "${packages[0]}"
rpm -V fping
/usr/sbin/fping --version
/usr/sbin/fping -4 -c 1 -t 1000 127.0.0.1
/usr/sbin/fping6 -c 1 -t 1000 ::1
getcap /usr/sbin/fping | grep -F 'cap_net_admin,cap_net_raw+ep'
runuser -u nobody -- /usr/sbin/fping -4 -c 1 -t 1000 127.0.0.1

cp "$work_dir"/rpmbuild/RPMS/x86_64/*.rpm "$output_dir/"
cp "$work_dir"/rpmbuild/SRPMS/*.rpm "$output_dir/"
rpm -qpi "${packages[0]}" > "$output_dir/rpm-info.txt"
rpm -qpR "${packages[0]}" > "$output_dir/rpm-requires.txt"
cd "$output_dir"
sha256sum ./*.rpm > SHA256SUMS
