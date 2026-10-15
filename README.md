## Github Status
[![Github Build Status](https://github.com/schweikert/fping/actions/workflows/test.yml/badge.svg)](https://github.com/schweikert/fping/actions/workflows/test.yml)
[![Github Build and Push Docker Image Status](https://github.com/schweikert/fping/actions/workflows/docker-deployment.yml/badge.svg)](https://github.com/schweikert/fping/actions/workflows/docker-deployment.yml)
[![Github CodeQL Status](https://github.com/schweikert/fping/actions/workflows/codeql-analysis.yml/badge.svg)](https://github.com/schweikert/fping/actions/workflows/codeql-analysis.yml)

## External Services
[![Coverage Status](https://coveralls.io/repos/github/schweikert/fping/badge.svg?branch=develop)](https://coveralls.io/github/schweikert/fping?branch=develop)
[![Coverity Scan Build Status](https://scan.coverity.com/projects/11559/badge.svg?flat=1)](https://scan.coverity.com/projects/schweikert-fping)

# fping

fping is a program to send ICMP echo probes to network hosts, similar to ping,
but much better performing when pinging multiple hosts. fping has a long long
story: Roland Schemers did publish a first version of it in 1992 and it has
established itself since then as a standard tool.

_Current maintainer_:  
  David Schweikert \<david@schweikert.ch\>

_Website_:  
  https://fping.org/

_Mailing-list_:  
  https://groups.google.com/group/fping-users

## Installation

If you want to install fping from source, proceed as follows:

0. Run `./autogen.sh`
   (only if you got the source from Github).
1. Run `./configure` with the correct arguments.
   (see: `./configure --help`)
2. Run `make; make install`.
3. Make fping either setuid, or, if under Linux:
   `sudo setcap cap_net_raw,cap_net_admin+ep fping`

If you can't run fping as root or can't use the cap_net_raw capability, you can
also run fping in unprivileged mode. This works on MacOS and also on Linux,
provided that your GID is included in the range defined in
`/proc/sys/net/ipv4/ping_group_range`. This is particularly useful for running
fping in rootless / unprivileged containers. The --fwmark option needs root or
cap_net_admin.

## CentOS 7 RPM builds

The [CentOS 7 RPM workflow](.github/workflows/centos7-rpm.yml) builds an x86_64
RPM from the checked-out source on every push (branches and tags), or manually
via **Actions > CentOS 7 RPM > Run workflow**. GitHub only offers the manual
button after the workflow exists on the repository's default branch. Enable
GitHub Actions in your fork if it is disabled. No additional secrets are needed.

The workflow runs Actions on Ubuntu and compiles inside `centos:7.9.2009`, using
GCC 4.8, glibc 2.17 and the signed CentOS Vault repositories. It does not build
on Ubuntu and relabel the result as an EL7 package. The version comes from
`configure.ac`; the release includes the workflow run number, attempt and commit
ID, for example `fping-5.5-0.ci123.1.git0123456789ab.el7.x86_64.rpm`.
CI releases sort before a future stable `5.5-1` RPM.

After a successful run, download the `fping-centos7-x86_64-...` artifact from its
Actions run page. It contains the binary RPM, source RPM, `SHA256SUMS`, package
metadata and runtime dependency list. Artifacts are retained for 30 days; build
logs are uploaded separately for 7 days, including when the build fails. This
workflow does not publish a GitHub Release or push a container image.

Extract the artifact, verify it, and install **only the binary RPM**:

```sh
sha256sum -c SHA256SUMS
sudo yum localinstall ./fping-*.el7.x86_64.rpm
/usr/sbin/fping --version
/usr/sbin/fping -4 -c 1 127.0.0.1
/usr/sbin/fping6 -c 1 ::1
```

`fping6` is a symlink to the dual-stack binary. RPM installs file capabilities
`cap_net_raw,cap_net_admin=ep` instead of a setuid executable. The workflow checks
RPM installation, file integrity, IPv4/IPv6 loopback and an unprivileged user's
IPv4 loopback probe. The filesystem must support file capabilities; `nosuid`
mounts and restricted containers may prevent their use. The RPMs are not signed
with a project signing key; checksums verify download integrity, not publisher
identity. Existing third-party fping packages may have different release
ordering or file ownership; review them before replacing an installation.

To reproduce the build locally on an x86_64 Linux Docker host:

```sh
mkdir -p artifacts
docker run --rm --platform linux/amd64 \
  --cap-add NET_RAW --cap-add NET_ADMIN \
  --sysctl net.ipv6.conf.all.disable_ipv6=0 \
  --sysctl net.ipv6.conf.default.disable_ipv6=0 \
  --mount "type=bind,source=$(pwd),target=/source,readonly" \
  --mount "type=bind,source=$(pwd)/artifacts,target=/output" \
  centos:7.9.2009 bash /source/ci/build-centos7-rpm.sh /output
```

CentOS 7 reached end of life on June 30, 2024. This package does not restore OS
security support. Builds depend on Docker Hub and the availability of
`https://vault.centos.org/7.9.2009/`; repository GPG and HTTPS verification remain
enabled. A container validates EL7 userspace compatibility, but uses the host's
kernel, so deployments on a real CentOS 7 kernel should still be tested. The
existing upstream test workflow remains separate from this packaging smoke test.

## EL9 RPM builds

The [EL9 RPM workflow](.github/workflows/el9-rpm.yml) runs on every push (branches
and tags), or manually via **Actions > EL9 RPM > Run workflow** once the workflow
exists on the default branch. It builds inside `rockylinux:9` using the official
Rocky Linux repositories, with no additional secrets. Packages target EL9
x86_64 userspace (Rocky Linux 9, AlmaLinux 9 and RHEL 9); validate installation
and behavior on your target distribution before deployment. EL7 and EL9 RPMs
are separate builds and should not be installed interchangeably.

Download the `fping-el9-x86_64-...` artifact from the successful run. It includes
binary and source RPMs, `SHA256SUMS`, package metadata and runtime dependencies,
with the same retention and smoke tests as the CentOS 7 workflow. EL9 packages
use the `.el9` release suffix, for example
`fping-5.5-0.ci123.1.git0123456789ab.el9.x86_64.rpm`.

```sh
sha256sum -c SHA256SUMS
sudo dnf install ./fping-*.el9.x86_64.rpm
/usr/sbin/fping --version
/usr/sbin/fping -4 -c 3 127.0.0.1
/usr/sbin/fping6 -c 3 ::1
```

To reproduce locally on an x86_64 Linux Docker host:

```sh
mkdir -p artifacts
docker run --rm --platform linux/amd64 \
  --cap-add NET_RAW --cap-add NET_ADMIN \
  --sysctl net.ipv6.conf.all.disable_ipv6=0 \
  --sysctl net.ipv6.conf.default.disable_ipv6=0 \
  --mount "type=bind,source=$(pwd),target=/source,readonly" \
  --mount "type=bind,source=$(pwd)/artifacts,target=/output" \
  rockylinux:9 bash /source/ci/build-el9-rpm.sh /output
```

Use a separate or empty output directory for each distribution. Builds require
Docker Hub and Rocky Linux repositories to be available. The `rockylinux:9` tag
tracks the current Rocky Linux 9 minor release; the build is not pinned to a
specific container digest. These RPMs are unsigned, and container smoke tests
do not replace testing on the target system's kernel and security policy.

## Usage

Have a look at the [fping(8)](doc/fping.pod) manual page for usage help.
(`fping -h` will also give a minimal help output.)

## Docker usage

You can use the current Docker image from the develop branch directly from GitHub.

Github Docker: `ghcr.io/schweikert/fping:latest`

The following example uses podman, but you can replace `podman` with `docker` if you prefer.

**Load or update Docker image**

```
podman pull ghcr.io/schweikert/fping:latest
```

**Run fping**

```
podman run --rm fping:latest 127.0.0.1
```

## Credits

* Original author:  Roland Schemers (schemers@stanford.edu)
* Previous maintainer:  RL "Bob" Morgan (morgan@stanford.edu)
* Initial IPv6 Support: Jeroen Massar (jeroen@unfix.org / jeroen@ipng.nl)
* Other contributors: see [CHANGELOG.md](CHANGELOG.md)
