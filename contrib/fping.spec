%{!?fping_version:%global fping_version 5.5}
%{!?fping_release:%global fping_release 1}

Summary: Send ICMP echo probes to multiple hosts
Name: fping
Version: %{fping_version}
Release: %{fping_release}%{?dist}
License: BSD with advertising
URL: https://fping.org/
Source0: https://fping.org/dist/%{name}-%{version}.tar.gz
BuildRequires: gcc, make, perl
BuildRequires: libcap
Requires: libcap

%description
fping is a program to send ICMP echo probes to network hosts, similar to ping,
but much better performing when pinging multiple hosts. fping has a very long
history: Roland Schemers did publish a first version of it in 1992 and it has
established itself since then as a standard tool for network diagnostics and
statistics.

%prep
%setup -q

%build
# GCC 4.8 defaults to gnu90, but the current sources use C99 declarations.
%configure --enable-ipv4 --enable-ipv6 CFLAGS="%{optflags} -std=gnu99"
make %{?_smp_mflags}

%install
make DESTDIR=%{buildroot} install
ln -s fping %{buildroot}%{_sbindir}/fping6
ln -s fping.8 %{buildroot}%{_mandir}/man8/fping6.8

%check
./src/fping --version

%files
%license COPYING
%doc README.md CHANGELOG.md
%attr(0755,root,root) %caps(cap_net_raw,cap_net_admin=ep) %{_sbindir}/fping
%{_sbindir}/fping6
%{_mandir}/man8/fping.8*
%{_mandir}/man8/fping6.8*

%changelog
* Mon Dec 24 2012 Marcus Vinicius Ferreira <ferreira.mv@gmail.com>
- Missing './configure' script when cloning from master.
- Making 'fping6'.
- Fix setuid permission to 'rwsr-xr-x'.
- doc files.
- Replacing setuid permission if 'setcap' is present on post-install.
- Using 'http://fping.org/dist/' for release source distributions.

* Mon Jul 16 2012 Stephen Schaefer <sschaefer@acm.org>
- Initial build

# vim:ft=spec:
