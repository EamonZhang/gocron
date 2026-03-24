#!/bin/bash

set -e

# Gocron Node RPM Package Builder
VERSION=${1:-"1.6"}
ARCH="x86_64"
RELEASE="1"
PACKAGE_NAME="gocron-node-${VERSION}-${RELEASE}.${ARCH}"

echo "Building RPM package for gocron node version ${VERSION}"

# Create package directory structure
echo "Creating directory structure..."
SPEC_DIR="rpmbuild/SPECS"
BUILD_ROOT="rpmbuild/BUILDROOT/${PACKAGE_NAME}"
mkdir -p "${SPEC_DIR}"
mkdir -p "${BUILD_ROOT}/usr/local/bin"
mkdir -p "${BUILD_ROOT}/etc/systemd/system"

# Copy binaries
if [ -f "bin/gocron-node" ]; then
    cp bin/gocron-node "${BUILD_ROOT}/usr/local/bin/"
    echo "Copied gocron-node binary"
else
    echo "Error: bin/gocron-node not found. Run 'make build' first."
    exit 1
fi

# Copy systemd service files
cp gocron-node.service "${BUILD_ROOT}/etc/systemd/system/"

# Create spec file
cat > "${SPEC_DIR}/gocron-node.spec" << EOF
Name: gocron-node
Version: ${VERSION}
Release: ${RELEASE}
Summary: A lightweight timing task scheduling and management system node component

License: MIT
BuildArch: ${ARCH}

Requires: systemd

%description
A lightweight timing task scheduling and management system node component for scheduled tasks written in Go.

%pre
# Create gocron user/group if not exists
if ! getent passwd gocron > /dev/null 2>&1; then
    /usr/sbin/useradd -r -s /sbin/nologin gocron 2>/dev/null || :
fi

%post
# Enable systemd service after installation
/usr/bin/systemctl daemon-reload >/dev/null 2>&1 || :
/usr/bin/systemctl enable gocron-node >/dev/null 2>&1 || :

%preun
# Stop service during removal
if [ \$1 = 0 ]; then
    /usr/bin/systemctl stop gocron-node >/dev/null 2>&1 || :
    /usr/bin/systemctl disable gocron-node >/dev/null 2>&1 || :
fi

%postun
# Reload systemd after removal
/usr/bin/systemctl daemon-reload >/dev/null 2>&1 || :

# Handle cleanup on complete package removal (not just upgrade)
if [ \$1 = 0 ]; then
    # User and group removal
    /usr/sbin/userdel gocron >/dev/null 2>&1 || :
    
    # Clean up binaries
    rm -f /usr/local/bin/gocron-node
fi

%files
%attr(755,gocron,gocron) /usr/local/bin/gocron-node
%attr(644,root,root) /etc/systemd/system/gocron-node.service

%changelog
* Sun Mar 23 2026 Cline Agent <cline@modelcontext.ai> - ${VERSION}-${RELEASE}
- Initial build for gocron-node
EOF

# Use rpmbuild to build the RPM package (only if rpmbuild is installed)
if command -v rpmbuild >/dev/null 2>&1; then
    # Build the RPM
    echo "Building RPM package..."
    rpmbuild --define "_topdir $PWD/rpmbuild" -bb "${SPEC_DIR}/gocron-node.spec"
    
    # Locate the output RPM file
    if [ -d "rpmbuild/RPMS/${ARCH}" ]; then
        ls -la "rpmbuild/RPMS/${ARCH}/"
    fi
else
    echo "Note: rpmbuild command not found, RPM package build is manual. You need to execute:"
    echo "rpmbuild --define '_topdir $PWD/rpmbuild' -bb ${SPEC_DIR}/gocron-node.spec"
fi

echo "RPM build directory structure created in ./rpmbuild/"
echo "Done! The gocron-node RPM build directory is ready."