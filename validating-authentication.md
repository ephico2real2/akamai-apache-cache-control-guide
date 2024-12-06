Validating Authentication Configuration
---

# Validating Authentication Configuration

This guide provides steps to validate the Akamai bypass cache authentication configuration using a Dockerized Apache setup. It includes tests for general files (like `test.html`) and authentication-specific endpoints (`login.html`, `login.php`), while optimizing caching for static assets.

---

## Table of Contents
- [Overview](#overview)
- [Directory Structure](#directory-structure)
- [Dockerfile for Testing](#dockerfile-for-testing)
- [bypass-cache-custom.conf](#bypass-cache-customconf)
- [Setup Steps](#setup-steps)
  - [Creating Directory Structure](#creating-directory-structure)
  - [Adding Files](#adding-files)
- [Running the Apache Server](#running-the-apache-server)
  - [Using Volume Mounts for `bypass-cache-custom.conf`](#using-volume-mounts-for-bypass-cache-customconf)
- [Automated Testing Script](#automated-testing-script)
- [Troubleshooting](#troubleshooting)
- [References](#references)

---

## Overview

This document explains how to validate the Akamai bypass cache authentication configuration locally using Docker and a custom Apache setup. The tests include:
- Verifying general cache behavior for `test.html`.
- Adding static files for authentication endpoints.
- Adding dynamic scripts for authentication flows.
- Optimizing static asset caching for performance.

---

## Directory Structure

```
bypass-cache-apache-test/
├── bypass-cache-custom.conf
├── static/
│   ├── login.html
│   ├── token.html
│   └── test.html
├── dynamic/
│   ├── login.php
│   └── token.php
├── Dockerfile
├── validating-bypass-cache.sh
└── README.md
```

---

## Dockerfile for Testing

```dockerfile
FROM quay.io/fedora/httpd-24:2.4

USER 0

# Install PHP for dynamic tests
RUN dnf install -y php && \
    dnf clean all

# Copy configuration files
COPY bypass-cache-custom.conf /etc/httpd/conf.d/bypass-cache-custom.conf

# Reset permissions
RUN /usr/libexec/httpd-prepare && rpm-file-permissions

EXPOSE 8080 8443

USER 1001

CMD ["/usr/bin/run-httpd"]
```

---

## bypass-cache-custom.conf

```bash
cat > bypass-cache-apache-test/bypass-cache-custom.conf <<'EOF'
<Directory "/var/www/html">
    Options FollowSymLinks
    AllowOverride None
    Require all granted

    # Default caching behavior for all files
    <IfModule mod_headers.c>
        <FilesMatch "\.(html|htm)$">
            Header set Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, private, max-age=0, s-maxage=0"
            Header set Pragma "no-cache"
            Header set Expires "Thu, 01 Jan 1970 00:00:00 GMT"
        </FilesMatch>
    </IfModule>

    # Disable ETags and Last-Modified for general cache prevention
    FileETag None
    Header unset ETag
    Header unset Last-Modified
</Directory>

<Directory "/var/www/html/auth">
    Options FollowSymLinks
    AllowOverride None
    Require all granted

    # Authentication-specific cache behavior
    <IfModule mod_headers.c>
        <FilesMatch "\.(html|php)$">
            Header set Cache-Control "private, no-cache, must-revalidate"
            Header set Edge-Control "bypass-cache"
            Header set Pragma "no-cache"
            Header set Expires "Thu, 01 Jan 1970 00:00:00 GMT"
        </FilesMatch>
    </IfModule>

    # Disable ETags and Last-Modified for authentication endpoints
    FileETag None
    Header unset ETag
    Header unset Last-Modified
</Directory>

<IfModule mod_rewrite.c>
    # Enable mod_rewrite for future extensibility
    RewriteEngine On
</IfModule>
EOF
```
---

## Setup Steps

### Creating Directory Structure

Run the following commands to set up the directory structure:
```bash
mkdir -p bypass-cache-apache-test/static
mkdir -p bypass-cache-apache-test/dynamic
```

---

### Adding Files

#### `test.html`
```bash
cat > bypass-cache-apache-test/static/test.html <<'EOF'
<html>
    <body>General Test Page</body>
</html>
EOF
```

#### `login.html`
```bash
cat > bypass-cache-apache-test/static/login.html <<'EOF'
<html>
    <body>Login Page</body>
</html>
EOF
```

#### `token.html`
```bash
cat > bypass-cache-apache-test/static/token.html <<'EOF'
<html>
    <body>Token Page</body>
</html>
EOF
```

#### `login.php`
```bash
cat > bypass-cache-apache-test/dynamic/login.php <<'EOF'
<?php
header("Cache-Control: private, no-cache, must-revalidate");
header("Edge-Control: bypass-cache");
echo "Dynamic Login Endpoint. Time: " . date("H:i:s");
?>
EOF
```

#### `token.php`
```bash
cat > bypass-cache-apache-test/dynamic/token.php <<'EOF'
<?php
header("Cache-Control: private, no-cache, must-revalidate");
header("Edge-Control: bypass-cache");
echo "Dynamic Token Endpoint. Time: " . date("H:i:s");
?>
EOF
```

---

## Running the Apache Server

### Option 1: Build and Run with Updated Configuration

1. Build the Docker image:
   ```bash
   podman build -t bypass-cache-apache-test .
   ```

2. Run the container:
   ```bash
   podman run -d -p 8080:8080 \
       -v $(pwd)/bypass-cache-apache-test/static:/var/www/html:Z \
       -v $(pwd)/bypass-cache-apache-test/dynamic:/var/www/html/auth:Z \
       --name bypass-cache-test localhost/bypass-cache-apache-test
   ```

---

### Option 2: Use Volume Mounts for `bypass-cache-custom.conf`

```bash
podman run -d -p 8080:8080 \
    -v $(pwd)/bypass-cache-apache-test/bypass-cache-custom.conf:/etc/httpd/conf.d/bypass-cache-custom.conf:Z \
    -v $(pwd)/bypass-cache-apache-test/static:/var/www/html:Z \
    -v $(pwd)/bypass-cache-apache-test/dynamic:/var/www/html/auth:Z \
    quay.io/fedora/httpd-24:2.4
```

---

## Automated Testing Script

### `validating-bypass-cache.sh`
```bash
cat > bypass-cache-apache-test/validating-bypass-cache.sh <<'EOF'
#!/bin/bash

ENDPOINTS=(
    "http://localhost:8080/test.html"
    "http://localhost:8080/auth/login.html"
    "http://localhost:8080/auth/token.html"
    "http://localhost:8080/auth/login.php"
    "http://localhost:8080/auth/token.php"
)

echo "Validating Cache Headers"
for endpoint in "${ENDPOINTS[@]}"; do
    echo "Testing $endpoint"
    curl -I $endpoint
    echo
done
EOF
chmod +x bypass-cache-apache-test/validating-bypass-cache.sh
```

### Run the Script
```bash
./bypass-cache-apache-test/validating-bypass-cache.sh
```

---

## Troubleshooting

### Check Apache Logs
```bash
podman logs bypass-cache-test
```

### Verify Configuration Syntax
```bash
podman exec bypass-cache-test httpd -t
```

### Common Errors and Fixes

- **403 Forbidden**: Ensure SELinux contexts are correctly applied for volume mounts.
- **404 Not Found**: Verify that the files are present in the correct directories.
- **500 Internal Server Error**: Check PHP syntax or missing PHP modules in the container.

---

## References

- [Akamai Cache Behavior Documentation](https://techdocs.akamai.com/property-mgr/docs/caching-2)
- [Apache mod_headers Documentation](https://httpd.apache.org/docs/2.4/mod/mod_headers.html)

---

