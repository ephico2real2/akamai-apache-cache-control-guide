POC Guide for `akamai-apache-cache-control-guide`:

---

# Akamai Apache Cache Control Guide

This guide demonstrates how to configure Apache HTTP Server with specific caching directives, particularly focused on preventing caching both at the Apache level and when using Akamai as a CDN.

---

## Table of Contents
- [Overview](#overview)
- [Directory Structure](#directory-structure)
- [Configuration Details](#configuration-details)
- [Apache Configuration Options](#apache-configuration-options)
- [Akamai Caching Behavior](#akamai-caching-behavior)
- [Build and Test](#build-and-test)
- [Testing Cache Headers](#testing-cache-headers)
- [Advantages of Using `custom.conf` in Lieu of `.htaccess`](#advantages-of-using-customconf-in-lieu-of-htaccess)
- [Why Use the `Expires` Header Directive](#why-use-the-expires-header-directive)
- [References](#references)

---

## Overview

This project provides a containerized Apache HTTP Server configuration that:
- Disables caching for specific file types
- Works effectively with Akamai CDN
- Uses proper security configurations
- Follows container best practices

---

## Directory Structure

```
akamai-apache-cache-control-guide/
├── Dockerfile
├── custom.conf
├── apache-test/
│   └── index.html
    └── test.html
└── README.md
```

---

## Configuration Details

### Dockerfile
```dockerfile
FROM quay.io/fedora/httpd-24:2.4

USER 0

# Install PHP for dynamic tests
RUN dnf install -y php && \
    dnf clean all

# Copy configuration files
#COPY custom.conf /etc/httpd/conf.d/custom.conf
#


# Reset permissions of filesystem to default values
RUN /usr/libexec/httpd-prepare && rpm-file-permissions

# Expose ports
EXPOSE 8080
EXPOSE 8443

# Switch to non-root user
USER 1001

# Start Apache
CMD ["/usr/bin/run-httpd"]
```

---

### Apache Configuration (`custom.conf`)
```apache
<Directory "/var/www/html">
    Options FollowSymLinks
    AllowOverride None
    Require all granted

    # Enable mod_rewrite
    <IfModule mod_rewrite.c>
        RewriteEngine On
    </IfModule>

    # Set caching headers
    <IfModule mod_headers.c>
        <FilesMatch "\.(js|css|xml|gz|html|htm)$">
            Header set Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, private, max-age=0, s-maxage=0"
            Header set Pragma "no-cache"
            Header set Expires "Thu, 01 Jan 1970 00:00:00 GMT"
            Header set Edge-Control "no-store, max-age=0"
            Header unset ETag
            Header unset Last-Modified
        </FilesMatch>
    </IfModule>

    FileETag None
</Directory>
```

### Switching from mod_zip to mod_deflate

```bash
cat > merge-custom.conf <<'EOF'
<Directory "/var/www/html">
    Options FollowSymLinks
    AllowOverride None
    Require all granted

    # Handle existing files or directories
    RewriteEngine On
    RewriteCond %{DOCUMENT_ROOT}%{REQUEST_URI} -f [OR]
    RewriteCond %{DOCUMENT_ROOT}%{REQUEST_URI} -d
    RewriteRule ^ - [L]

    # Redirect all other requests to index.html
    RewriteRule ^ /index.html

    # Enable mod_rewrite for extensibility
    <IfModule mod_rewrite.c>
        RewriteEngine On
    </IfModule>

    # Set caching headers for static files
    <IfModule mod_headers.c>
        <FilesMatch "\.(js|css|xml|gz|html|htm)$">
            Header set Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, private, max-age=0, s-maxage=0"
            Header set Pragma "no-cache"
            Header set Expires "Thu, 01 Jan 1970 00:00:00 GMT"
            Header set Edge-Control "no-store, max-age=0"
            Header unset ETag
            Header unset Last-Modified
        </FilesMatch>
    </IfModule>

    # Compression for specified file types
   <IfModule mod_deflate.c>
    # Enable compression for specific MIME types
    AddOutputFilterByType DEFLATE text/html text/plain text/xml
    AddOutputFilterByType DEFLATE text/css application/javascript
    AddOutputFilterByType DEFLATE application/json application/xml
    AddOutputFilterByType DEFLATE application/x-font-ttf application/font-woff
    AddOutputFilterByType DEFLATE application/vnd.ms-fontobject
    AddOutputFilterByType DEFLATE image/svg+xml image/x-icon

    # Optional: Exclude specific file types or already compressed files
    SetEnvIfNoCase Request_URI \.(?:gif|jpe?g|png|zip|tar\.gz|tgz)$ no-gzip
    SetEnvIfNoCase rspheader ^Content-Encoding:.*gzip.* no-gzip

    # Optional: Handle compatibility with older browsers
    BrowserMatch ^Mozilla/4 gzip-only-text/html
    BrowserMatch ^Mozilla/4\.0[678] no-gzip
    BrowserMatch \bMSIE !no-gzip !gzip-only-text/html

    # Add caching and compression-specific Vary headers
    Header append Vary User-Agent env=!dont-vary
    Header append Vary Accept-Encoding
</IfModule>

    # Disable ETags and Last-Modified for general cache prevention
    FileETag None
</Directory>
EOF
```

---

## Apache Configuration Options

### Directory Options
- `Options FollowSymLinks`: Allows use of symbolic links
- `AllowOverride None`: Disables `.htaccess` files for better performance
- `Require all granted`: Allows access to the directory

### Cache Control Headers
- `no-store`: Prevents storing the response in any cache
- `no-cache`: Requires validation with origin before using cached content
- `must-revalidate`: Forces strict validation of cached content
- `proxy-revalidate`: Forces proxy servers to revalidate
- `private`: Prevents caching by intermediary caches
- `max-age=0`: Sets cache lifetime to zero
- `s-maxage=0`: Sets shared (proxy) cache lifetime to zero

### Additional Headers
- `Pragma: no-cache`: HTTP/1.0 backwards compatibility
- `Expires`: Sets explicit expiration date in the past, ensuring the resource is always considered stale.
- `Edge-Control`: Akamai-specific directive for edge caching
- `FileETag None`: Disables ETag generation

---

## Akamai Caching Behavior

According to [Akamai's documentation](https://techdocs.akamai.com/property-mgr/docs/caching-2):

> Akamai servers don't cache objects when the `no-store` or `no-cache` directives are present in the `Cache-Control` header, or when the `private` directive is present and Honor private option is enabled. The `Expires` header and the Default maxage setting are not honored if any of these `Cache-Control` directives is present: `no-store`, `no-cache`, `max-age`, `s-maxage`, `private` or `pre-check`

Our configuration uses multiple directives to ensure content is not cached:
- `no-store` and `no-cache` prevent Akamai caching
- `private` prevents caching when Honor private is enabled
- `max-age=0` and `s-maxage=0` explicitly set zero cache duration
- `Edge-Control` header provides additional Akamai-specific cache control

---

## Build and Test

### 1. Build the Docker Image
```bash
podman build -t custom-apache-standalone .
```

### 2 A. Create Test Content in index.html
```bash
mkdir apache-test
echo "<h1>Welcome to OCP Apache LAB!</h1>" > apache-test/index.html
```

### 2B. Create GZIp Test Content in test.html
```bash
cat > apache-test/test.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Compression Test</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
        }
        h1 {
            color: #333;
        }
    </style>
</head>
<body>
    <h1>Testing GZIP Compression</h1>
    <p>This is a sample HTML file to test if GZIP compression is enabled on your Apache server.</p>
    <p>The file includes some text, inline styles, and HTML elements to ensure that compression applies to a typical web page.</p>
</body>
</html>
EOF
```

### 3. Run the Container
```bash
podman run -d -p 8080:8080 \
  -v $(pwd)/apache-test:/var/www/html/:Z \
  --name test-htaccess localhost/custom-apache-standalone
```

---

## Testing Cache Headers

Test the configuration using `curl`:

```bash
curl -I http://localhost:8080/test.html
```

Expected output:
```http
Cache-Control: no-store, no-cache, must-revalidate, proxy-revalidate, private, max-age=0, s-maxage=0
Pragma: no-cache
Expires: Thu, 01 Jan 1970 00:00:00 GMT
Edge-Control: no-store, max-age=0
```

```bash
curl -I --compressed http://localhost:8080/test.html
```

Expected output:
```http
HTTP/1.1 200 OK
Date: Fri, 06 Dec 2024 04:00:32 GMT
Server: Apache/2.4.62 (Fedora Linux) OpenSSL/3.2.2
Accept-Ranges: bytes
Vary: Accept-Encoding,User-Agent
Content-Encoding: gzip
Cache-Control: no-store, no-cache, must-revalidate, proxy-revalidate, private, max-age=0, s-maxage=0
Pragma: no-cache
Expires: Thu, 01 Jan 1970 00:00:00 GMT
Edge-Control: no-store, max-age=0
Content-Length: 397
Content-Type: text/html; charset=UTF-8
```


## comparison of the old mod_gzip configuration with the updated mod_deflate configuration:

```apache
# OLD Configuration (mod_gzip)                # NEW Configuration (mod_deflate)
<IfModule mod_gzip.c>                         <IfModule mod_deflate.c>
    mod_gzip_on Yes                               # Enabled by module loading
    mod_gzip_dechunk Yes                         # Handled automatically

    # File type handling                          # MIME type handling (more specific)
    mod_gzip_item_include file                    AddOutputFilterByType DEFLATE text/html text/plain text/xml
    .(html?|txt|css|js|php|pl)$                  AddOutputFilterByType DEFLATE text/css application/javascript
                                                 AddOutputFilterByType DEFLATE application/json application/xml
    
    # MIME type handling                          # Font types (new additions)
    mod_gzip_item_include mime ^text/.*           AddOutputFilterByType DEFLATE application/x-font-ttf application/font-woff
    mod_gzip_item_include mime                    AddOutputFilterByType DEFLATE application/vnd.ms-fontobject
    ^application/x-javascript.*
    mod_gzip_item_include mime ^image/.*          # Vector images (specifically targeted)
                                                 AddOutputFilterByType DEFLATE image/svg+xml image/x-icon

    # Exclude already compressed                  # Improved exclusion handling
    mod_gzip_item_exclude rspheader               SetEnvIfNoCase Request_URI \.(?:gif|jpe?g|png|zip|tar\.gz|tgz)$ no-gzip
    ^Content-Encoding:.*gzip.*                    SetEnvIfNoCase rspheader ^Content-Encoding:.*gzip.* no-gzip

                                                 # Browser compatibility (new)
                                                 BrowserMatch ^Mozilla/4 gzip-only-text/html
                                                 BrowserMatch ^Mozilla/4\.0[678] no-gzip
                                                 BrowserMatch \bMSIE !no-gzip !gzip-only-text/html

                                                 # Vary headers (new)
                                                 Header append Vary User-Agent env=!dont-vary
                                                 Header append Vary Accept-Encoding
</IfModule>                                    </IfModule>
```

Key Improvements in mod_deflate:
1. More specific MIME type targeting
2. Better browser compatibility handling
3. Added support for modern file types:
   - Fonts (ttf, woff)
   - JSON
   - SVG images
4. Proper caching headers with Vary
5. More granular control over compression

The mod_deflate configuration is:
- More maintainable
- Better compatible with modern web standards
- More efficient in handling compression
- Includes proper cache control integration


---

## Advantages of Using `custom.conf` in Lieu of `.htaccess`

1. **Performance**:
   - Apache checks for `.htaccess` files on every request, even if none exist, which can slow down performance. Using `custom.conf` eliminates this overhead.

2. **Centralized Configuration**:
   - `custom.conf` consolidates all configuration settings in one place, making it easier to manage and maintain.

3. **Global Scope**:
   - Rules in `custom.conf` can apply globally to directories, unlike `.htaccess`, which only affects the directory where it resides.

4. **Security**:
   - Disabling `.htaccess` with `AllowOverride None` enhances security by preventing users from creating potentially harmful configurations.

5. **Ease of Debugging**:
   - All configurations are centralized in `custom.conf`, making it easier to locate and fix issues compared to searching for `.htaccess` files across multiple directories.

6. **Best Practices for Containerized Environments**:
   - `.htaccess` is not ideal for containers where configuration should be part of the image. Using `custom.conf` ensures that the configuration is built into the container and is consistent across environments.

---

## Why Use the `Expires` Header Directive

The `Expires` header is used to explicitly set an expiration date for a resource, which is essential for the following reasons:

1. **Forcing Content to Be Considered Stale**:
   - By setting the expiration date to a time in the past (e.g., `Thu, 01 Jan 1970 00:00:00 GMT`), the browser and any intermediary caches (e.g., Akamai, proxies) will treat the content as stale and always fetch it from the origin server.

2. **Backward Compatibility**:
   - The `Expires` header provides additional assurance for systems that may not fully respect or support modern `Cache-Control` directives.

3. **Complementing Cache-Control**:
   - While `Cache-Control` headers are more modern and flexible, the `Expires` header serves as a fallback for HTTP/1.0 clients and systems.

4. **CDN Behavior**:
   - CDNs like Akamai can recognize the `Expires` header and treat resources accordingly, ensuring consistency with caching policies.

---

## References

- [Akamai Property Manager Documentation](https://techdocs.akamai.com/property-mgr/docs/caching-2)
- [Apache HTTP Server Documentation](https://httpd.apache.org/docs/2.4/)
- [Apache Module mod_headers](https://httpd.apache.org/docs/2.4/mod/mod_headers.html)

---

