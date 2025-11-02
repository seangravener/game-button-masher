# SSL Setup Sequence Diagrams

## Initial SSL Certificate Setup

This diagram shows the complete flow when running `./scripts/setup-ssl.sh` for the first time.

```mermaid
sequenceDiagram
    actor User
    participant Script as setup-ssl.sh
    participant FileSystem as File System
    participant Compose as Podman Compose
    participant Nginx as Nginx Container
    participant App as Button Smasher App
    participant Certbot as Certbot Container
    participant LetsEncrypt as Let's Encrypt CA

    User->>Script: Run ./scripts/setup-ssl.sh
    Script->>User: Prompt: Enable SSL? (y/n)
    User->>Script: y

    Script->>User: Prompt: Enter domain name
    User->>Script: smasher.example.com

    Script->>User: Prompt: Enter email
    User->>Script: admin@example.com

    Note over Script: Validate domain format
    Script->>Script: Check DNS resolution (dig)
    Script->>User: ✓ Domain resolves to: 1.2.3.4

    Note over Script,FileSystem: Setup Phase
    Script->>FileSystem: Create certbot/www/
    Script->>FileSystem: Create certbot/conf/
    Script->>FileSystem: Create nginx/conf/active.conf<br/>(HTTP-only, ACME challenge ready)

    Note over Script,App: Start Services (HTTP Mode)
    Script->>Compose: docker-compose -f ssl.yml up -d
    Compose->>App: Start button-smasher container
    App->>App: Listen on port 3000
    Compose->>Nginx: Start nginx container
    Nginx->>Nginx: Listen on port 80<br/>Serve ACME challenges from /var/www/certbot

    Script->>Script: Sleep 5 seconds (wait for nginx)

    Note over Script,LetsEncrypt: Certificate Acquisition
    Script->>Compose: run certbot certonly --webroot
    Compose->>Certbot: Start certbot (one-time run)
    Certbot->>LetsEncrypt: Request certificate for smasher.example.com
    LetsEncrypt->>LetsEncrypt: Generate challenge token
    LetsEncrypt->>Certbot: Challenge: http://smasher.example.com/.well-known/acme-challenge/TOKEN

    Certbot->>FileSystem: Write challenge file to certbot/www/
    Certbot->>Certbot: Notify Let's Encrypt: Ready for validation

    LetsEncrypt->>Nginx: GET /.well-known/acme-challenge/TOKEN
    Nginx->>FileSystem: Read certbot/www/.well-known/acme-challenge/TOKEN
    FileSystem->>Nginx: Return challenge file
    Nginx->>LetsEncrypt: Return challenge response

    LetsEncrypt->>LetsEncrypt: Validate challenge response
    LetsEncrypt->>Certbot: ✓ Challenge passed! Here's your certificate

    Certbot->>FileSystem: Save fullchain.pem to certbot/conf/live/domain/
    Certbot->>FileSystem: Save privkey.pem to certbot/conf/live/domain/
    Certbot->>Script: Exit code 0 (success)

    Note over Script,Nginx: Configure HTTPS
    Script->>FileSystem: Update nginx/conf/active.conf<br/>(HTTPS config with SSL certs)
    Script->>Compose: docker-compose -f config/docker/docker-compose.yml down
    Compose->>Nginx: Stop nginx
    Compose->>App: Stop button-smasher

    Script->>Compose: docker-compose -f ssl.yml up -d
    Compose->>App: Start button-smasher
    App->>App: Listen on port 3000
    Compose->>Nginx: Start nginx with SSL config
    Nginx->>FileSystem: Load SSL certificates
    Nginx->>Nginx: Listen on port 80 (HTTP → HTTPS redirect)
    Nginx->>Nginx: Listen on port 443 (HTTPS)
    Compose->>Certbot: Start certbot (auto-renewal mode)

    Script->>User: ✓ SSL Setup Complete!<br/>Access at https://smasher.example.com
```

## Automatic Certificate Renewal Process

This diagram shows what happens every 12 hours for automatic certificate renewal.

```mermaid
sequenceDiagram
    participant Certbot as Certbot Container<br/>(Auto-Renewal Loop)
    participant FileSystem as File System
    participant LetsEncrypt as Let's Encrypt CA
    participant Nginx as Nginx Container
    participant User as Browser/User

    Note over Certbot: Every 12 hours...
    Certbot->>Certbot: Wake up from 12h sleep
    Certbot->>FileSystem: Check certificate expiry date

    alt Certificate expires in < 30 days
        Note over Certbot,LetsEncrypt: Renewal Needed
        Certbot->>LetsEncrypt: Request certificate renewal
        LetsEncrypt->>LetsEncrypt: Generate new challenge
        LetsEncrypt->>Certbot: Challenge token

        Certbot->>FileSystem: Write challenge to certbot/www/
        Certbot->>LetsEncrypt: Ready for validation

        LetsEncrypt->>Nginx: GET /.well-known/acme-challenge/TOKEN
        Nginx->>FileSystem: Read challenge file
        FileSystem->>Nginx: Return file
        Nginx->>LetsEncrypt: Challenge response

        LetsEncrypt->>LetsEncrypt: Validate
        LetsEncrypt->>Certbot: ✓ New certificate issued

        Certbot->>FileSystem: Save new fullchain.pem
        Certbot->>FileSystem: Save new privkey.pem

        Note over Nginx: Every 6 hours, Nginx reloads automatically
        Note over Nginx: Next reload will pick up new certificate

    else Certificate still valid (> 30 days)
        Certbot->>Certbot: No renewal needed
    end

    Certbot->>Certbot: Sleep 12h

    Note over User,Nginx: Meanwhile, users continue to access site normally
    User->>Nginx: HTTPS request
    Nginx->>FileSystem: Load SSL certificate
    Nginx->>User: Secure connection ✓
```

## User Request Flow (HTTPS)

This diagram shows what happens when a user visits your site after SSL is configured.

```mermaid
sequenceDiagram
    actor User as User Browser
    participant Nginx as Nginx<br/>(Reverse Proxy)
    participant App as Button Smasher<br/>App (Port 3000)
    participant SocketIO as Socket.IO<br/>Connection

    Note over User,App: HTTP Request (redirected to HTTPS)
    User->>Nginx: http://smasher.example.com
    Nginx->>User: 301 Redirect to https://smasher.example.com

    Note over User,App: HTTPS Connection
    User->>Nginx: https://smasher.example.com
    Nginx->>Nginx: Load SSL certificate<br/>Establish TLS connection
    Nginx->>User: TLS Handshake ✓

    User->>Nginx: GET / (HTTPS)
    Nginx->>App: Proxy to http://button-smasher:3000/
    App->>App: Serve index.html
    App->>Nginx: Return HTML + assets
    Nginx->>User: Return response (HTTPS)

    Note over User,SocketIO: WebSocket Connection (Secure)
    User->>Nginx: Upgrade: websocket (wss://)
    Nginx->>Nginx: Detect WebSocket upgrade
    Nginx->>App: Proxy WebSocket to :3000
    App->>SocketIO: Establish Socket.IO connection
    SocketIO->>App: Connection established
    App->>Nginx: WebSocket upgrade success
    Nginx->>User: WebSocket connected (WSS)

    Note over User,SocketIO: Game Communication
    User->>Nginx: Game action (wss://)
    Nginx->>App: Proxy WebSocket frame
    App->>SocketIO: Handle game event
    SocketIO->>App: Broadcast to room
    App->>Nginx: Response via WebSocket
    Nginx->>User: Real-time update (encrypted)
```

## Container Architecture Diagram

This diagram shows the overall container architecture with SSL.

```mermaid
graph TB
    subgraph Internet
        User[👤 User Browser]
        LetsEncrypt[🔐 Let's Encrypt CA]
    end

    subgraph "Host Server (Ports 80, 443)"
        Nginx[🌐 Nginx Reverse Proxy<br/>Ports: 80, 443]

        subgraph "Internal Network (app-network)"
            App[🎮 Button Smasher App<br/>Port: 3000<br/>Internal only]
            Certbot[🔑 Certbot<br/>Auto-renewal daemon]
        end

        subgraph "Volumes"
            CertConf[(📁 certbot/conf<br/>SSL Certificates)]
            CertWww[(📁 certbot/www<br/>ACME Challenges)]
            NginxConf[(📁 nginx/conf<br/>Nginx Config)]
        end
    end

    User -->|HTTP :80| Nginx
    User -->|HTTPS :443| Nginx
    Nginx -->|Proxy :3000| App

    Nginx -.->|Read config| NginxConf
    Nginx -.->|Read certs| CertConf
    Nginx -.->|Serve ACME| CertWww

    Certbot -.->|Write certs| CertConf
    Certbot -.->|Write challenges| CertWww
    Certbot <-->|Validate| LetsEncrypt
    LetsEncrypt -->|Verify challenges| Nginx

    style User fill:#4A90E2
    style Nginx fill:#50E3C2
    style App fill:#F5A623
    style Certbot fill:#7ED321
    style LetsEncrypt fill:#BD10E0
    style CertConf fill:#D0021B
    style CertWww fill:#D0021B
    style NginxConf fill:#D0021B
```

## SSL Setup Decision Flow

This diagram shows the decision tree in the setup script.

```mermaid
flowchart TD
    Start([User runs ./scripts/setup-ssl.sh]) --> CheckCompose{Podman or Docker<br/>Compose installed?}

    CheckCompose -->|No| Error1[❌ Error: Install compose first]
    CheckCompose -->|Yes| AskSSL{Ask: Enable SSL?}

    AskSSL -->|No| HTTPOnly[Setup HTTP-only mode]
    HTTPOnly --> CopyHTTP[Copy http-only.conf to active.conf]
    CopyHTTP --> StartHTTP[Start with docker-compose.yml]
    StartHTTP --> SuccessHTTP[✓ Running on HTTP :3000]

    AskSSL -->|Yes| AskDomain[Prompt for domain name]
    AskDomain --> ValidateDomain{Valid domain<br/>format?}

    ValidateDomain -->|No| Warning1[⚠️ Warning: Format looks wrong]
    Warning1 --> Continue1{Continue anyway?}
    Continue1 -->|No| AskDomain
    Continue1 -->|Yes| CheckDNS

    ValidateDomain -->|Yes| CheckDNS[Check DNS resolution]
    CheckDNS --> DNSResolves{Domain<br/>resolves?}

    DNSResolves -->|No| Warning2[⚠️ Warning: No DNS resolution]
    Warning2 --> Continue2{Continue anyway?}
    Continue2 -->|No| AskDomain
    Continue2 -->|Yes| AskEmail

    DNSResolves -->|Yes| ShowIP[✓ Domain resolves to IP]
    ShowIP --> AskEmail[Prompt for email]

    AskEmail --> ValidateEmail{Valid email<br/>format?}
    ValidateEmail -->|No| Warning3[⚠️ Warning: Email looks invalid]
    Warning3 --> Continue3{Continue anyway?}
    Continue3 -->|No| AskEmail
    Continue3 -->|Yes| CreateDirs

    ValidateEmail -->|Yes| CreateDirs[Create certbot directories]
    CreateDirs --> CreateConfig[Create initial Nginx config<br/>HTTP + ACME challenge]
    CreateConfig --> StartServices[Start nginx + app containers]
    StartServices --> Wait[Wait 5 seconds for nginx]
    Wait --> RunCertbot[Run certbot certonly]

    RunCertbot --> CertSuccess{Certificate<br/>obtained?}

    CertSuccess -->|No| ShowErrors[❌ Display error message]
    ShowErrors --> CommonIssues[Show common issues:<br/>- DNS not pointing to server<br/>- Ports not open<br/>- Firewall blocking]
    CommonIssues --> Fallback[Fallback to HTTP-only mode]
    Fallback --> SuccessHTTP

    CertSuccess -->|Yes| UpdateNginx[Update nginx config with SSL]
    UpdateNginx --> RestartAll[Restart all services with SSL]
    RestartAll --> StartCertbotDaemon[Start certbot auto-renewal]
    StartCertbotDaemon --> SuccessSSL[✓ Running on HTTPS!<br/>https://domain.com]

    style Start fill:#4A90E2
    style SuccessHTTP fill:#7ED321
    style SuccessSSL fill:#50E3C2
    style Error1 fill:#D0021B
    style ShowErrors fill:#F5A623
```

## Certificate Lifecycle

```mermaid
gantt
    title SSL Certificate Lifecycle (90 Days)
    dateFormat YYYY-MM-DD

    section Certificate Status
    Valid Certificate (Days 1-60)    :cert1, 2024-01-01, 60d
    Renewal Window (Days 60-90)      :cert2, 2024-03-01, 30d

    section Certbot Actions
    Initial Certificate              :milestone, init, 2024-01-01, 0d
    Auto-check every 12h             :check, 2024-01-01, 90d
    First Renewal Attempt (Day 60)   :milestone, renew1, 2024-03-01, 0d
    Renewal Success                  :milestone, success, 2024-03-01, 0d
    New Certificate Valid            :cert3, 2024-03-01, 90d

    section Nginx Reloads
    Auto-reload every 6h             :reload, 2024-01-01, 90d
```

---

## How to Use These Diagrams

### View on GitHub
These Mermaid diagrams render automatically on GitHub. Just push this file and view it on GitHub.com.

### View Locally
1. **VS Code**: Install "Markdown Preview Mermaid Support" extension
2. **Browser**: Use [Mermaid Live Editor](https://mermaid.live/)
3. **Command Line**: Install `mermaid-cli` and run `mmdc -i SSL-SEQUENCE.md`

### Generate Images
```bash
# Install mermaid-cli
npm install -g @mermaid-js/mermaid-cli

# Generate PNG images
mmdc -i SSL-SEQUENCE.md -o ssl-sequence.png
```

## Legend

- 🔐 = SSL/Security related
- 🌐 = Network/Web related
- 🎮 = Application
- 👤 = User/Human
- 📁 = File/Volume
- ✓ = Success
- ❌ = Error
- ⚠️ = Warning
