To test caching and proper behavior for **images** and **JSON files**, follow these steps:

---

## **1. Prepare Test Files**
Create test files for images and JSON data in your project directory (e.g., `apache-test`).

### **Add a Sample Image**
Save or generate a sample image file (e.g., `test-image.jpg`) in the `apache-test` folder.

```bash
# Move or create an image
cp test-image.jpg apache-test/test-image.jpg
```

### **Add a Sample JSON File**
Create a `test-data.json` file in the `apache-test` folder.

```bash
cat <<EOF > apache-test/test-data.json
{
  "message": "Hello, this is a JSON test!",
  "timestamp": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
}
EOF
```

---

## **2. Update the Apache Configuration**
Ensure your Apache configuration (`merge-custom.conf`) includes caching rules for images and JSON files.

### Example Configuration:
```apache
<IfModule mod_headers.c>
    # Cache static assets (images, JSON) for 1 year
    <FilesMatch "\.(jpg|jpeg|png|gif|ico|svg|json)$">
        Header set Cache-Control "max-age=31536000, public"
    </FilesMatch>
</IfModule>

<IfModule mod_expires.c>
    ExpiresActive On
    ExpiresByType image/jpeg "access plus 1 year"
    ExpiresByType application/json "access plus 1 year"
</IfModule>
```

Restart Apache after updating the configuration:

```bash
./run-apache-test.sh
```

---

## **3. Test the Image File**

### **Fetch the Image**
Use `curl` to request the image:

```bash
curl -I http://localhost:8080/test-image.jpg
```

**Expected Headers**:
```http
HTTP/1.1 200 OK
Cache-Control: max-age=31536000, public
Content-Type: image/jpeg
```

### **Verify in the Browser**
1. Open your browser and navigate to:
   ```
   http://localhost:8080/test-image.jpg
   ```
2. Confirm that the image loads correctly.
3. Check the **Network** tab in Developer Tools:
   - The `Cache-Control` header should show `max-age=31536000, public`.
   - Reload the page to confirm if the browser uses the cached version.

---

## **4. Test the JSON File**

### **Fetch the JSON File**
Use `curl` to request the JSON file:

```bash
curl -I http://localhost:8080/test-data.json
```

**Expected Headers**:
```http
HTTP/1.1 200 OK
Cache-Control: max-age=31536000, public
Content-Type: application/json
```

### **Fetch the JSON Content**
Use `curl` to fetch the JSON content:

```bash
curl http://localhost:8080/test-data.json
```

**Expected Output**:
```json
{
  "message": "Hello, this is a JSON test!",
  "timestamp": "2024-12-06T04:00:00Z"
}
```

---

## **5. Test Cache Behavior**
1. **Modify the Files**:
   - Change the content of `test-data.json` or replace `test-image.jpg` with a new image.
   - Example: Update `test-data.json`:
     ```bash
     echo '{"message": "Cache updated!", "timestamp": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"}' > apache-test/test-data.json
     ```

2. **Bypass the Cache**:
   - Test if the cached version is served:
     ```bash
     curl http://localhost:8080/test-data.json
     ```
   - Add a query string to bypass the cache:
     ```bash
     curl http://localhost:8080/test-data.json?version=2
     ```

3. **Test in Browser**:
   - Reload the files in the browser.
   - Confirm the cached behavior by forcing a refresh (`Ctrl+F5` or equivalent for Mac).

---

## **6. Summary of Testing**

| **File Type** | **Test URL**                        | **Expected Cache Header**            |
|---------------|-------------------------------------|---------------------------------------|
| Image         | `http://localhost:8080/test-image.jpg` | `Cache-Control: max-age=31536000, public` |
| JSON          | `http://localhost:8080/test-data.json` | `Cache-Control: max-age=31536000, public` |

---

## **Best Practices for Testing**
- Use `curl` to inspect headers and verify caching rules.
- Use browser Developer Tools to confirm cache behavior.
- Modify files and use query strings to simulate cache invalidation.

