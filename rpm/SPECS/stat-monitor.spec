%global app_root %{_datadir}/%{name}

Summary: A simple remote status monitor for computers on a network
Name: statmonitor
Version: 0.8.1
Release: 1%{?dist}
Group: System Environment/Daemons
License: MIT
URL: http://www.github.com/blm768/stat-monitor
Source0: %{name}-%{version}.gem
#Requires: 
#...
#Requires(post):   chkconfig
#...
#BuildRequires: rubygem-rspec
#...
BuildArch: noarch

%description
A simple remote status monitor for computers on a network

%package doc
Summary: Documentation for %{name}
Group: Documentation
Requires:%{name} = %{version}-%{release}

%description doc
Documentation for %{name}

%prep
gem unpack -V %{SOURCE0}
%setup -q -D -T -n %{name}-%{version}

%build

%install
mkdir -p %{buildroot}%{app_root}
#mkdir -p %{buildroot}%{_initddir}
mkdir -p %{buildroot}%{_bindir}
mkdir -p %{buildroot}/etc/stat-monitor

cp -r * %{buildroot}%{app_root}
#mv %{buildroot}%{app_root}/support/fedora/%{name} %{buildroot}%{_initddir}
ln -s %{app_root}/bin/stat-monitor-client %{buildroot}%{_bindir}
mv %{buildroot}%{app_root}/config/* %{buildroot}/etc/stat-monitor
find %{buildroot}%{app_root}/lib -type f | xargs chmod -x
#chmod 0755 %{buildroot}%{_initddir}/%{name}
chmod 0755 %{buildroot}%{app_root}/bin/stat-monitor-client
rm -rf %{buildroot}%{app_root}/support
rdoc --op %{buildroot}%{_defaultdocdir}/%{name}

%post
# This adds the proper /etc/rc*.d links for the script
#/sbin/chkconfig --add %{name}

%files
#%{_initddir}/%{name}
%{_bindir}/stat-monitor-client
%dir %{app_root}/
%{app_root}/bin
%{app_root}/ext
%{app_root}/lib
/etc/stat-monitor
#...

%files doc
%{_defaultdocdir}/%{name}
%{app_root}/spec
%{app_root}/%{name}.gemspec
%{app_root}/Rakefile
%{app_root}/Gemfile
%{app_root}/LICENSE
%{app_root}/README.md
%{app_root}/snapshot


%changelog
#...