# Container Security Guide

## Vulnerability Scanning

### Scan with Trivy (Recommended)
```bash
# Install Trivy
# Ubuntu/Debian
sudo apt-get install wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install trivy

# Scan the image
trivy image button-smasher:latest

# Scan with severity filter
trivy image --severity HIGH,CRITICAL button-smasher:latest
```

### Scan with Grype
```bash
# Install Grype
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin

# Scan the image
grype button-smasher:latest
```

### Scan with Podman/Docker Scout (if available)
```bash
# Docker Scout
docker scout cves button-smasher:latest

# Podman with Trivy
podman run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image button-smasher:latest
```

## Dockerfile Options

### Option 1: Alpine-based (Current - Best balance)
**File**: `Dockerfile`
- Small size (~100-150MB)
- Regular security updates
- Good compatibility
- Recommended for most use cases

```bash
podman build -f config/docker/Dockerfile -t button-smasher:alpine .
```

### Option 2: Distroless (Maximum Security)
**File**: `Dockerfile.distroless`
- Minimal attack surface
- No shell, no package manager
- Google-maintained
- Best for production security

```bash
podman build -f Dockerfile.distroless -t button-smasher:distroless .
```

**Note**: Distroless images have no shell, making debugging harder. Use for production only.

## Security Best Practices

### 1. Keep Base Images Updated
```bash
# Rebuild regularly to get security patches
podman build --no-cache -t button-smasher:latest .

# Check for updates
podman pull docker.io/library/node:22-alpine3.20
```

### 2. Scan Before Deployment
```bash
# Add to CI/CD pipeline
trivy image --exit-code 1 --severity HIGH,CRITICAL button-smasher:latest
```

### 3. Run with Limited Permissions
```bash
# Drop all capabilities
podman run --rm -p 3000:3000 \
  --cap-drop=ALL \
  --security-opt=no-new-privileges:true \
  --read-only \
  --tmpfs /tmp \
  button-smasher:latest
```

### 4. Use SELinux/AppArmor (Linux)
```bash
# With SELinux labels (Podman)
podman run --rm -p 3000:3000 \
  --security-opt label=type:container_runtime_t \
  button-smasher:latest

# With AppArmor (Docker)
docker run --rm -p 3000:3000 \
  --security-opt apparmor=docker-default \
  button-smasher:latest
```

### 5. Network Isolation
```bash
# Create isolated network
podman network create button-smasher-net

# Run with custom network
podman run -d -p 3000:3000 \
  --network button-smasher-net \
  --name button-smasher \
  button-smasher:latest
```

## Dependency Security

### Audit npm dependencies
```bash
cd server/
npm audit
npm audit fix
```

### Use npm-check-updates
```bash
npm install -g npm-check-updates
ncu -u
npm install
```

## Image Signing (Podman)

### Sign images for verification
```bash
# Generate GPG key if needed
gpg --full-generate-key

# Sign the image
podman image sign \
  --sign-by you@example.com \
  docker://localhost/button-smasher:latest

# Verify signature
podman image trust set -f /path/to/policy.json localhost/button-smasher
podman pull --signature-policy /path/to/policy.json localhost/button-smasher:latest
```

## Runtime Security Monitoring

### Use Falco for runtime security
```bash
# Install Falco
curl -s https://falco.org/repo/falcosecurity-3672BA8F.asc | apt-key add -
echo "deb https://download.falco.org/packages/deb stable main" | tee -a /etc/apt/sources.list.d/falcosecurity.list
apt-get update
apt-get install -y falco

# Monitor container behavior
falco
```

## Vulnerability Remediation Priority

1. **CRITICAL**: Patch immediately
   - RCE (Remote Code Execution)
   - Privilege escalation
   - Authentication bypass

2. **HIGH**: Patch within 24-48 hours
   - Information disclosure
   - DoS vulnerabilities

3. **MEDIUM/LOW**: Schedule for next maintenance window

## Automated Security in CI/CD

### GitHub Actions Example
```yaml
name: Security Scan

on: [push, pull_request]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Build image
        run: podman build -f config/docker/Dockerfile -t button-smasher:${{ github.sha }} .

      - name: Run Trivy scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: button-smasher:${{ github.sha }}
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'

      - name: Upload results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'
```

## Additional Resources

- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [Node.js Security Best Practices](https://nodejs.org/en/docs/guides/security/)
- [Snyk Node.js Security](https://snyk.io/learn/nodejs-security/)
