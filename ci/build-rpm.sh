#!/bin/bash
set -euo pipefail

# Shared packaging stage; distribution wrappers install the build dependencies.
source_dir=$(cd "$(dirname "$0")/.." && pwd)
output_dir=${1:-/output}
dist=${2:?An RPM distribution suffix is required (el7 or el9)}
[[ "$dist" == el7 || "$dist" == el9 ]]
mkdir -p "$output_dir"
output_dir=$(cd "$output_dir" && pwd)
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

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
    --define "dist .$dist"

# Exercise the installed RPM, not just the binary in the build tree.
packages=("$work_dir/rpmbuild/RPMS/x86_64/"fping-[0-9]*.x86_64.rpm)
[[ ${#packages[@]} == 1 && -f "${packages[0]}" ]]
rpm -Uvh "${packages[0]}"
rpm -V fping
/usr/sbin/fping --version
/usr/sbin/fping -4 -c 1 -t 1000 127.0.0.1
/usr/sbin/fping6 -c 1 -t 1000 ::1
# libcap uses different capability formatting on EL7 and EL9.
capabilities=$(getcap /usr/sbin/fping)
[[ "$capabilities" == *cap_net_admin* && "$capabilities" == *cap_net_raw* ]]
[[ "$capabilities" == *+ep || "$capabilities" == *=ep ]]
runuser -u nobody -- /usr/sbin/fping -4 -c 1 -t 1000 127.0.0.1

cp "$work_dir"/rpmbuild/RPMS/x86_64/*.rpm "$output_dir/"
cp "$work_dir"/rpmbuild/SRPMS/*.rpm "$output_dir/"
rpm -qpi "${packages[0]}" > "$output_dir/rpm-info.txt"
rpm -qpR "${packages[0]}" > "$output_dir/rpm-requires.txt"
cd "$output_dir"
sha256sum ./*.rpm > SHA256SUMS
