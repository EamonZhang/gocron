#!/bin/bash

set -e

# Gocron Web Debian Package Builder
VERSION=${1:-"1.6"}
ARCH="amd64"
PACKAGE_NAME="gocron-web_${VERSION}_${ARCH}"

echo "Building Debian package for gocron web version ${VERSION}"

# Create package directory structure
echo "Creating directory structure..."
PKG_DIR="pkg/${PACKAGE_NAME}"
mkdir -p "${PKG_DIR}/DEBIAN"
mkdir -p "${PKG_DIR}/usr/local/bin"
mkdir -p "${PKG_DIR}/etc/systemd/system"
mkdir -p "${PKG_DIR}/etc/gocron/conf"

# Copy binaries
if [ -f "bin/gocron" ]; then
    cp bin/gocron "${PKG_DIR}/usr/local/bin/"
    echo "Copied gocron binary"
else
    echo "Error: bin/gocron not found. Run 'make build' first."
    exit 1
fi

# Copy systemd service files
cp gocron-web.service "${PKG_DIR}/etc/systemd/system/"

# Create control file
cat > "${PKG_DIR}/DEBIAN/control" << EOF
Package: gocron-web
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: ${ARCH}
Depends: systemd
Maintainer: Gocron Maintainers
Description: A lightweight timing task scheduling and management system web component.
 This tool provides web interface for managing scheduled tasks written in Go.
EOF

# Make sure binary files are executable
chmod 755 "${PKG_DIR}/usr/local/bin/gocron"

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
systemctl enable gocron-web || true
chown -R gocron:gocron /etc/gocron 2>/dev/null || true

# Create log directory and set permissions for gocron user
mkdir -p /var/log/gocron
chown gocron:gocron /var/log/gocron
chmod 755 /var/log/gocron
EOF
chmod 755 "${PKG_DIR}/DEBIAN/postinst"

# Create prerm script
cat > "${PKG_DIR}/DEBIAN/prerm" << 'EOF'
#!/bin/bash
set -e
systemctl stop gocron-web || true
systemctl disable gocron-web || true
EOF
chmod 755 "${PKG_DIR}/DEBIAN/prerm"

# Create postrm script
cat > "${PKG_DIR}/DEBIAN/postrm" << 'EOF'
#!/bin/bash
set -e
systemctl daemon-reload || true

if [ "$1" = "purge" ]; then
  # Remove all gocron related files and directories
  # Check and stop service gracefully if it still exists
  if [ -f /etc/systemd/system/gocron-web.service ]; then
    systemctl stop gocron-web || true
    systemctl disable gocron-web || true
  fi
  
  # Remove all gocron related files and directories  
  rm -rf /var/log/gocron
  rm -rf /etc/gocron
  rm -rf /usr/local/bin/gocron

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
# cp "${PKG_DIR}.deb" ./
# ls -lh "${PACKAGE_NAME}.deb"

echo "Done! The gocron-web Debian package is ready."
