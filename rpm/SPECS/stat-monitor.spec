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
BuildRequires: rubygems
#...

%global gem_dir /usr/share/rubygems/
%global gem_instdir %{gem_dir}/gems/%{gem_name}-%{version}/
%global gem_docdir %{gem_dir}/doc/%{gem_name}-%{version}/
%global gem_cachefile %{gem_dir}/cache/%{gem_name}-%{version}.gem
%global gem_specfile %{gem_dir}/specifications/%{gem_name}-%{version}.gemspec
%global gem_name statmonitor
%global gem_extdir %{_libdir}/gems/ext/%{gem_name}-%{version}/

%description
A simple remote status monitor for computers on a network

%package doc
Summary: Documentation for %{name}
Group: Documentation
Requires:%{name} = %{version}-%{release}

%description doc
Documentation for %{name}

%prep
#To do: move to subdir?
%setup -q -D -T -n .

cp %{SOURCE0} .

%build
gem install -V \
  --install-dir ./%{gem_dir} \
  --local \
  --bindir ./%{_bindir} \
  --force \
  --rdoc \
  %{gem_name}-%{version}.gem


%install

mkdir -p %{buildroot}%{gem_dir}
cp -a ./%{gem_dir}/* %{buildroot}%{gem_dir}/

mkdir -p %{buildroot}%{_bindir}
cp -a ./%{_bindir}/* %{buildroot}%{_bindir}

mkdir -p %{buildroot}/etc/stat-monitor
cp -a ./%{gem_instdir}/config/* %{buildroot}/etc/stat-monitor

%check
#To do: run tests.
#rake

%post
# This adds the proper /etc/rc*.d links for the script
#/sbin/chkconfig --add %{name}

%files
#%{_initddir}/%{name}
%{_bindir}/stat-monitor-client
%{gem_instdir}
%{gem_docdir}
%{gem_cachefile}
%{gem_specfile}
/etc/stat-monitor
#...



%changelog
#...