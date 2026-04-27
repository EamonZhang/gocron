#!/bin/bash

set -e

# Gocron Node Debian Package Builder
VERSION=${1:-"1.7"}
ARCH="amd64"
PACKAGE_NAME="gocron-node_${VERSION}_${ARCH}"

echo "Building Debian package for gocron node version ${VERSION}"

# Create package directory structure
echo "Creating directory structure..."
PKG_DIR="pkg/${PACKAGE_NAME}"
mkdir -p "${PKG_DIR}/DEBIAN"
mkdir -p "${PKG_DIR}/usr/local/bin"
mkdir -p "${PKG_DIR}/etc/systemd/system"

# Copy binaries
if [ -f "bin/gocron-node" ]; then
    cp bin/gocron-node "${PKG_DIR}/usr/local/bin/"
    echo "Copied gocron-node binary"
else
    echo "Error: bin/gocron-node not found. Run 'make build' first."
    exit 1
fi

# Copy systemd service files
cp gocron-node.service "${PKG_DIR}/etc/systemd/system/"

# Note: gocron-node does not require configuration files.
# All configuration is managed by the gocron-web package if installed.

# Create control file
cat > "${PKG_DIR}/DEBIAN/control" << EOF
Package: gocron-node
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: ${ARCH}
Depends: systemd
Maintainer: Gocron Maintainers
Description: A lightweight timing task scheduling and management system node component.
 This tool provides task execution node service for scheduled tasks written in Go.
EOF

# Make sure binary files are executable
chmod 755 "${PKG_DIR}/usr/local/bin/gocron-node"

# Create preinst script for user creation
cat > "${PKG_DIR}/DEBIAN/preinst" << 'EOF'
#!/bin/bash
set -e
if ! getent passwd gocron > /dev/null 2>&1; then
   adduser --system --group --quiet --disabled-password --shell /bin/false gocron
fi
EOF
chmod 755 "${PKG_DIR}/DEBIAN/preinst"

# Create postinst script for systemd services
cat > "${PKG_DIR}/DEBIAN/postinst" << 'EOF'
#!/bin/bash
set -e
systemctl daemon-reload || true
systemctl enable gocron-node || true
EOF
chmod 755 "${PKG_DIR}/DEBIAN/postinst"

# Create prerm script
cat > "${PKG_DIR}/DEBIAN/prerm" << 'EOF'
#!/bin/bash
set -e
systemctl stop gocron-node || true
systemctl disable gocron-node || true
EOF
chmod 755 "${PKG_DIR}/DEBIAN/prerm"

# Create postrm script
cat > "${PKG_DIR}/DEBIAN/postrm" << 'EOF'
#!/bin/bash
set -e
systemctl daemon-reload || true

if [ "$1" = "purge" ]; then
  # Check and stop service gracefully if it still exists
  if [ -f /etc/systemd/system/gocron-node.service ]; then
    systemctl stop gocron-node || true
    systemctl disable gocron-node || true
  fi
  
  # Remove the gocron binary
  rm -f /usr/local/bin/gocron-node

  # Remove the gocron user and group
  deluser --system --remove-home --group gocron >/dev/null 2>&1 || true
fi
EOF
chmod 755 "${PKG_DIR}/DEBIAN/postrm"

# Calculate package size
SIZE=$(du -sb ${PKG_DIR} | cut -f1)

sed -i "s/^Installed-Size:.*/Installed-Size: $((SIZE / 1024))/" "${PKG_DIR}/DEBIAN/control"

# Build the package
echo "Building Debian package..."
dpkg-deb --build --root-owner-group "${PKG_DIR}"

echo "Debian package built successfully: ${PACKAGE_NAME}.deb"

echo "Done! The gocron-node Debian package is ready."