#!/bin/bash

set -e

# Gocron Web RPM Package Builder
VERSION=${1:-"1.7"}
ARCH="x86_64"
RELEASE="1"
PACKAGE_NAME="gocron-web-${VERSION}-${RELEASE}.${ARCH}"

echo "Building RPM package for gocron web version ${VERSION}"

# Create package directory structure
echo "Creating directory structure..."
SPEC_DIR="rpmbuild/SPECS"
BUILD_ROOT="rpmbuild/BUILDROOT/${PACKAGE_NAME}"
mkdir -p "${SPEC_DIR}"
mkdir -p "${BUILD_ROOT}/usr/local/bin"
mkdir -p "${BUILD_ROOT}/etc/systemd/system"
mkdir -p "${BUILD_ROOT}/etc/gocron/conf"

# Copy binaries
if [ -f "bin/gocron" ]; then
    cp bin/gocron "${BUILD_ROOT}/usr/local/bin/"
    echo "Copied gocron binary"
else
    echo "Error: bin/gocron not found. Run 'make build' first."
    exit 1
fi

# Copy systemd service files
cp gocron-web.service "${BUILD_ROOT}/etc/systemd/system/"
cp conf/app.ini "${BUILD_ROOT}/etc/gocron/conf/"

# Create spec file
cat > "${SPEC_DIR}/gocron-web.spec" << EOF
Name: gocron-web
Version: ${VERSION}
Release: ${RELEASE}
Summary: A lightweight timing task scheduling and management system web component

License: MIT
BuildArch: ${ARCH}

Requires: systemd

%description
A lightweight timing task scheduling and management system web component written in Go.

%pre
# Create gocron user/group if not exists
if ! getent passwd gocron > /dev/null 2>&1; then
    /usr/sbin/useradd -r -s /sbin/nologin gocron 2>/dev/null || :
fi

%post
# Create the log directory with appropriate permissions
mkdir -p /var/log/gocron
chown gocron:gocron /var/log/gocron
chmod 755 /var/log/gocron

# Enable systemd service after installation
/usr/bin/systemctl daemon-reload >/dev/null 2>&1 || :
/usr/bin/systemctl enable gocron-web >/dev/null 2>&1 || :

# Set ownership for configuration
chown -R gocron:gocron /etc/gocron 2>/dev/null || :

%preun
# Stop service during removal
if [ \$1 = 0 ]; then
    /usr/bin/systemctl stop gocron-web >/dev/null 2>&1 || :
    /usr/bin/systemctl disable gocron-web >/dev/null 2>&1 || :
fi

%postun
# Reload systemd after removal
/usr/bin/systemctl daemon-reload >/dev/null 2>&1 || :

# Handle cleanup on complete package removal (not just upgrade)
if [ \$1 = 0 ]; then
    # User and group removal
    /usr/sbin/userdel gocron >/dev/null 2>&1 || :
    
    # Clean up directories
    rm -rf /var/log/gocron
    rm -rf /etc/gocron
    rm -f /usr/local/bin/gocron
fi

%files
%attr(755,gocron,gocron) /usr/local/bin/gocron
%attr(644,gocron,gocron) /etc/gocron/conf/
%attr(644,root,root) /etc/systemd/system/gocron-web.service
%config(noreplace) /etc/gocron/conf/app.ini

%changelog
* Sun Mar 23 2026 Cline Agent <cline@modelcontext.ai> - ${VERSION}-${RELEASE}
- Initial build for gocron-web
EOF

# Use rpmbuild to build the RPM package (only if rpmbuild is installed)
if command -v rpmbuild >/dev/null 2>&1; then
    # Build the RPM
    echo "Building RPM package..."
    rpmbuild --define "_topdir $PWD/rpmbuild" -bb "${SPEC_DIR}/gocron-web.spec"
    
    # Locate the output RPM file
    if [ -d "rpmbuild/RPMS/${ARCH}" ]; then
        ls -la "rpmbuild/RPMS/${ARCH}/"
    fi
else
    echo "Note: rpmbuild command not found, RPM package build is manual. You need to execute:"
    echo "rpmbuild --define '_topdir $PWD/rpmbuild' -bb ${SPEC_DIR}/gocron-web.spec"
fi

echo "RPM build directory structure created in ./rpmbuild/"
echo "Done! The gocron-web RPM build directory is ready."