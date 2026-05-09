# Docker Compose – Praktische Referenz: Möglichkeiten, Multi-Service-Setups & Tool-Vergleich

> Konsolidierte Praxisdokumentation für WSL2/Debian-Umgebungen: Vollständige `docker-compose.yml`-Referenz, Best Practices für Multi-Service-Stacks, strukturierter Vor-/Nachteil-Vergleich und detaillierter Tool-Guide für Portainer, Dockge, Yacht, Dozzle, Watchtower und DIUN.

***

## Teil 1 – Vollständige `docker-compose.yml`-Referenz

### 1.1 Topologische Übersicht aller Schlüsselelemente

Eine `docker-compose.yml` kennt genau **sieben Top-Level-Elemente**, von denen jedes eine klar abgegrenzte Infrastrukturrolle übernimmt:[^1][^2]

```
docker-compose.yml
│
├── services/        → Container-Definitionen (das Herzstück)
├── networks/        → Virtuelle Netzwerke zwischen Containern
├── volumes/         → Persistenter Datenspeicher
├── secrets/         → Sensible Zugangsdaten (verschlüsselt)
├── configs/         → Konfigurationsdateien (read-only Mounts)
├── include/         → Modulare Einbindung anderer Compose-Dateien (ab v2.20)
└── (version)        → Veraltet! Ab Compose v2 / 2025 weglassen
```

### 1.2 `services` – Vollständige Schlüssel-Referenz

```yaml
services:
  mein-service:
    # ── Image & Build ──────────────────────────────────
    image: nginx:alpine                    # Fertiges Image
    build:                                 # ODER: Lokaler Build
      context: ./app
      dockerfile: Dockerfile.prod
      target: production                   # Multi-Stage Target
      args:
        BUILD_VERSION: "1.2.3"

    # ── Identität & Lifecycle ──────────────────────────
    container_name: mein-nginx
    hostname: nginx-host
    restart: unless-stopped               # always | on-failure | no
    profiles: ["production"]              # Nur mit COMPOSE_PROFILES=production

    # ── Ports & Netzwerk ───────────────────────────────
    ports:
      - "8080:80"                          # Host:Container
      - "127.0.0.1:8443:443"              # Nur Loopback binden
    expose:
      - "9000"                             # Nur intern (kein Host-Port)
    networks:
      - frontend
      - backend
    dns:
      - 172.20.0.2                         # Custom DNS für diesen Container
    extra_hosts:
      - "db.intern:192.168.1.10"

    # ── Umgebungsvariablen ─────────────────────────────
    environment:
      - NODE_ENV=production
      - API_URL=${API_URL}                 # Aus .env-Datei
    env_file:
      - .env                               # Ganze Datei einlesen
      - .env.local                         # Lokale Overrides

    # ── Volumes & Dateisystem ──────────────────────────
    volumes:
      - ./html:/usr/share/nginx/html       # Bind Mount
      - app_data:/data                     # Named Volume
      - type: tmpfs                        # RAM-Disk
        target: /tmp
    working_dir: /app
    user: "1000:1000"                      # Non-Root-User

    # ── Secrets & Configs ──────────────────────────────
    secrets:
      - db_password                        # Unter /run/secrets/db_password
      - source: api_key
        target: /app/config/api.key       # Benutzerdefinierter Pfad
    configs:
      - source: nginx_conf
        target: /etc/nginx/nginx.conf

    # ── Abhängigkeiten & Reihenfolge ───────────────────
    depends_on:
      db:
        condition: service_healthy         # Warten bis DB wirklich bereit
      cache:
        condition: service_started         # Nur warten bis gestartet

    # ── Health Check ───────────────────────────────────
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s                    # Wartezeit vor erstem Check

    # ── Startbefehl ────────────────────────────────────
    command: ["npm", "start"]
    entrypoint: ["/docker-entrypoint.sh"]

    # ── Ressourcenlimits ───────────────────────────────
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 512M
        reservations:
          memory: 256M

    # ── Logging ────────────────────────────────────────
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "5"

    # ── Linux-Capabilities (für Netzwerkdienste) ───────
    cap_add:
      - NET_ADMIN
    sysctls:
      - net.ipv4.ip_forward=1

    # ── Labels (für Traefik, Watchtower, etc.) ─────────
    labels:
      - "traefik.enable=true"
      - "com.centurylinklabs.watchtower.enable=true"
```

### 1.3 `networks` – Vollständige Referenz

```yaml
networks:
  # Standard Bridge-Netzwerk
  frontend:
    driver: bridge

  # Internes Netzwerk ohne externe Konnektivität
  internal:
    driver: bridge
    internal: true             # Kein Internetzugang aus diesem Netz

  # Benutzerdefiniertes Subnetz mit festen IPs
  dns-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/24
          gateway: 172.20.0.1

  # Bereits existierendes externes Netzwerk einbinden
  proxy:
    external: true             # Muss vorher existieren (z.B. Traefik-Netz)
    name: proxy                # Exakter Name des externen Netzwerks

  # macvlan für eigene IP im Heimnetz (für DNS-Server)
  macvlan-net:
    driver: macvlan
    driver_opts:
      parent: eth0
    ipam:
      config:
        - subnet: 192.168.1.0/24
          gateway: 192.168.1.1
```

### 1.4 `volumes` – Vollständige Referenz

```yaml
volumes:
  # Einfaches Named Volume (von Docker verwaltet)
  db_data:

  # Named Volume mit Treiber-Optionen
  nfs_data:
    driver: local
    driver_opts:
      type: nfs
      o: addr=192.168.1.5,rw
      device: ":/mnt/share"

  # Bind Mount als Named Volume (explizit)
  config_vol:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /opt/myapp/config

  # Externes Volume (bereits existiert)
  legacy_data:
    external: true
```

### 1.5 `secrets` und `configs` im Vergleich

```yaml
secrets:
  # Aus lokaler Datei
  db_password:
    file: ./secrets/db_password.txt

  # Aus Umgebungsvariable (selten)
  api_token:
    environment: "API_TOKEN_VAR"

configs:
  # Konfigurationsdatei (read-only, nicht verschlüsselt)
  nginx_conf:
    file: ./nginx.conf

  # Extern (bereits in Docker gespeichert)
  ssl_cert:
    external: true
```

| Aspekt | `secrets` | `configs` |
|--------|-----------|-----------|
| **Inhalt** | Passwörter, Tokens, Keys | nginx.conf, prometheus.yml |
| **Mount-Pfad Standard** | `/run/secrets/<name>` | Benutzerdefiniert |
| **Verschlüsselung** | Ja (in Swarm-Modus) | Nein |
| **Zugriffsrechte** | Restricted (600) | Lesbar (444) |
| **Laufzeit** | Read-only | Read-only |
| **Swarm-Unterstützung** | Nativ | Nativ |

***

### 1.6 Alle wichtigen `docker compose`-Befehle

```bash
# ── Start / Stop ─────────────────────────────────────
docker compose up -d                     # Alle Services starten (detached)
docker compose up -d --build             # Mit Image-Rebuild
docker compose up -d service1 service2  # Nur bestimmte Services
docker compose up --watch               # Dev-Modus: Live-Reload bei Änderungen
docker compose down                      # Services stoppen + Netzwerke entfernen
docker compose down -v                   # Inkl. Löschen aller Volumes
docker compose down --remove-orphans     # Verwaiste Container entfernen
docker compose restart [service]         # Service neu starten
docker compose start / stop [service]   # Starten / Stoppen ohne Remove

# ── Status & Debugging ─────────────────────────────────
docker compose ps                        # Status aller Services
docker compose ps -a                     # Inkl. gestoppter Container
docker compose logs -f                   # Live-Logs aller Services
docker compose logs -f --tail=100 db     # Letzten 100 Zeilen, live
docker compose top                       # Prozesse aller Container
docker compose stats                     # Ressourcenverbrauch live

# ── Interaktion ────────────────────────────────────────
docker compose exec db bash              # Shell in laufenden Container
docker compose exec -u root db bash     # Als root
docker compose run --rm migrate          # Einmaligen Job ausführen
docker compose run --rm app npm test    # Test-Command ausführen

# ── Images & Konfiguration ─────────────────────────────
docker compose pull                      # Alle Images aktualisieren
docker compose build                     # Images neu bauen
docker compose push                      # Images in Registry pushen
docker compose config                    # Zusammengeführte Konfiguration prüfen
docker compose config --quiet           # Nur Fehler ausgeben

# ── Multi-File-Modus ───────────────────────────────────
docker compose -f base.yml -f prod.yml up -d
docker compose -p myprojekt up -d       # Expliziter Projektname
COMPOSE_PROFILES=development docker compose up -d

# ── Cleanup ────────────────────────────────────────────
docker compose rm -f                     # Gestoppte Container löschen
docker system prune --all --volumes     # Alles aufräumen (Vorsicht!)
```

***

## Teil 2 – Mehrere Dienste: Beispiele & Best Practices

### 2.1 Zwei vollständig isolierte Apps in einer Datei

Das Geheimnis liegt in **separaten benannten Netzwerken**: Services im selben Stack, aber ohne gegenseitige Kommunikationsmöglichkeit:[^3][^4]

```yaml
# Zwei völlig unabhängige Anwendungen in einer Datei
# Netzwerke isolieren sie voneinander

services:
  # ════ Anwendung 1: Vaultwarden (Passwort-Manager) ═══
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: unless-stopped
    ports:
      - "8080:80"
    volumes:
      - vaultwarden_data:/data
    environment:
      - WEBSOCKET_ENABLED=true
      - SIGNUPS_ALLOWED=false
      - DOMAIN=https://vault.intern
    networks:
      - vaultwarden_net   # Eigenes isoliertes Netzwerk

  # ════ Anwendung 2: Gitea (Git-Server) ════════════════
  gitea:
    image: gitea/gitea:latest
    container_name: gitea
    restart: unless-stopped
    ports:
      - "3000:3000"
      - "2222:22"
    environment:
      - GITEA__database__DB_TYPE=sqlite3
      - USER_UID=1000
      - USER_GID=1000
    volumes:
      - gitea_data:/data
    networks:
      - gitea_net          # Eigenes isoliertes Netzwerk

  # ════ Anwendung 3: Heimdall (Dashboard) ══════════════
  heimdall:
    image: lscr.io/linuxserver/heimdall:latest
    container_name: heimdall
    restart: unless-stopped
    ports:
      - "7080:80"
    volumes:
      - heimdall_data:/config
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Berlin
    networks:
      - heimdall_net       # Eigenes isoliertes Netzwerk

networks:
  vaultwarden_net:
    driver: bridge
  gitea_net:
    driver: bridge
  heimdall_net:
    driver: bridge

volumes:
  vaultwarden_data:
  gitea_data:
  heimdall_data:
```

### 2.2 Shared-Network-Pattern: Apps teilen einen Reverse-Proxy

```yaml
# Traefik als zentraler Reverse-Proxy
# Alle Apps registrieren sich darüber

services:
  # ── Reverse-Proxy (gemeinsam genutzt) ────────────────
  traefik:
    image: traefik:v3.2
    container_name: traefik
    restart: unless-stopped
    command:
      - "--providers.docker.exposedByDefault=false"
      - "--entryPoints.websecure.address=:443"
      - "--entryPoints.web.address=:80"
      - "--entryPoints.web.http.redirections.entryPoint.to=websecure"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - traefik_certs:/certs
    networks:
      - proxy            # Im Proxy-Netzwerk erreichbar

  # ── App A: Nextcloud ──────────────────────────────────
  nextcloud:
    image: nextcloud:latest
    container_name: nextcloud
    restart: unless-stopped
    volumes:
      - nextcloud_data:/var/www/html
    environment:
      - NEXTCLOUD_TRUSTED_DOMAINS=cloud.intern
    depends_on:
      nextcloud-db:
        condition: service_healthy
    networks:
      - proxy              # Traefik-Zugriff
      - nextcloud_internal # Nur interne DB-Kommunikation
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.nextcloud.rule=Host(`cloud.intern`)"
      - "traefik.http.routers.nextcloud.entrypoints=websecure"
      - "traefik.http.services.nextcloud.loadbalancer.server.port=80"

  nextcloud-db:
    image: mariadb:10.11
    container_name: nextcloud-db
    restart: unless-stopped
    volumes:
      - nextcloud_db:/var/lib/mysql
    environment:
      MYSQL_DATABASE: nextcloud
      MYSQL_ROOT_PASSWORD_FILE: /run/secrets/nc_db_root
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect"]
      interval: 10s
      retries: 5
    secrets:
      - nc_db_root
    networks:
      - nextcloud_internal  # Kein Proxy-Zugriff! Nur intern.

  # ── App B: Immich (Foto-Manager) ──────────────────────
  immich-server:
    image: ghcr.io/immich-app/immich-server:release
    container_name: immich-server
    restart: unless-stopped
    volumes:
      - immich_uploads:/usr/src/app/upload
    environment:
      - DB_HOSTNAME=immich-db
      - REDIS_HOSTNAME=immich-redis
    depends_on:
      immich-db:
        condition: service_healthy
      immich-redis:
        condition: service_started
    networks:
      - proxy
      - immich_internal
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.immich.rule=Host(`fotos.intern`)"
      - "traefik.http.routers.immich.entrypoints=websecure"
      - "traefik.http.services.immich.loadbalancer.server.port=2283"

  immich-db:
    image: tensorchord/pgvecto-rs:pg14-v0.2.0
    container_name: immich-db
    restart: unless-stopped
    volumes:
      - immich_db:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: immich
      POSTGRES_USER: immich
      POSTGRES_PASSWORD_FILE: /run/secrets/immich_db_pass
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U immich"]
      interval: 10s
      retries: 5
    secrets:
      - immich_db_pass
    networks:
      - immich_internal

  immich-redis:
    image: redis:7-alpine
    container_name: immich-redis
    restart: unless-stopped
    networks:
      - immich_internal

networks:
  proxy:
    name: proxy
    driver: bridge
  nextcloud_internal:
    driver: bridge
    internal: true     # Kein Internetzugang
  immich_internal:
    driver: bridge
    internal: true

volumes:
  nextcloud_data:
  nextcloud_db:
  immich_uploads:
  immich_db:
  traefik_certs:

secrets:
  nc_db_root:
    file: ./secrets/nc_db_root.txt
  immich_db_pass:
    file: ./secrets/immich_db_pass.txt
```

### 2.3 Best Practices Checkliste für Multi-Service-Stacks

```
✅ Netzwerke
   - Jede logische Anwendungsgruppe bekommt ihr eigenes Netzwerk
   - Datenbanken NUR im internen Netzwerk (internal: true)
   - Shared Services (Traefik, Monitoring) in gemeinsamen Netzwerken
   - Explizite Netzwerknamen (name: proxy) für externe Referenzen

✅ Secrets & Credentials
   - NIEMALS Passwörter als Plaintext in der Compose-Datei
   - Docker Secrets für Produktionsumgebungen
   - .env-Datei für lokale Entwicklung (in .gitignore!)
   - .env.example mit leerem Inhalt ins Repository committen

✅ Health Checks & Abhängigkeiten
   - Alle Services mit depends_on auf tatsächlichen Health-Checks
   - start_period für Datenbanken (Initialisierung braucht Zeit)
   - Eigene healthcheck-Befehle pro Image-Typ dokumentieren

✅ Ressourcen & Stabilität
   - deploy.resources.limits für JEDEN Service setzen
   - restart: unless-stopped für alle dauerhaften Services
   - Logging-Rotation (max-size, max-file) für alle Services

✅ Volumes & Daten
   - Named Volumes statt Bind Mounts für Produktionsdaten
   - Backup-Strategie für jedes Named Volume dokumentieren
   - external: true für Volumes zwischen Stacks sharen

✅ Wartbarkeit
   - container_name explizit vergeben
   - Labels für Dokumentation/Kategorisierung nutzen
   - version-Feld weglassen (ab Compose v2 obsolet)
   - TZ=Europe/Berlin in allen Services setzen
```

***

## Teil 3 – Single vs. Multiple Compose-Dateien

### 3.1 Architekturvarianten im Überblick

Es gibt vier etablierte Strukturierungsmodelle:[^5][^6][^3]

| Modell | Struktur | Einsatz |
|--------|----------|---------|
| **Monolith** | Alles in einer `docker-compose.yml` | ≤5 Services, Einzelperson |
| **Multi-File** | Eine Datei pro App in eigenem Ordner | 5–20 Services, Teams |
| **Master + Include** | Master-Datei inkludiert Unter-Dateien | Homelab, strukturiertes Solo-Setup |
| **Override-Pattern** | `base.yml` + `prod.yml` / `dev.yml` | Multi-Environment-Deployments |

### 3.2 Vollständiger Vor-/Nachteil-Vergleich

#### Modell 1: Alles in einer Datei (Monolith)

| ✅ Vorteile | ❌ Nachteile |
|------------|------------|
| Ein Befehl startet/stoppt alles | Datei wächst schnell unübersichtlich |
| Zentrale Netzwerkverwaltung | `docker compose down` stoppt ALLES |
| Einfache gegenseitige Service-Referenzen | Einzelner Service aktualisieren = ganzen Stack anfassen |
| Ein `.env`-File für alles | Bei Konflikten: ganzer Stack betroffen |
| Einfaches Backup der Konfiguration | Team-Konflikte bei paralleler Bearbeitung[^3] |
| Atomare Deployments | Schwer testbar in CI (zu viele Services) |

#### Modell 2: Separate Dateien pro Anwendung

| ✅ Vorteile | ❌ Nachteile |
|------------|------------|
| Klare Verantwortungsgrenzen | Cross-App-Kommunikation via externen Netzwerken |
| Unabhängige Lifecycle-Kontrolle | Mehrere `.env`-Dateien → Duplikation |
| Parallelarbeit in Teams möglich | Kein globales `up` für alles |
| Einfaches Hinzufügen/Entfernen von Apps | Overhead bei Ordnerstruktur-Pflege |
| Kleinere, besser reviewbare Dateien | Gemeinsame Secrets müssen synchron gehalten werden |
| Unabhängige Updates | |

#### Modell 3: Master-Datei mit `include`

```yaml
# /opt/docker/docker-compose.yml – Master-Datei
include:
  - path: ./db-cluster/docker-compose.yml
  - path: ./proxy/docker-compose.yml
  - path: ./monitoring/docker-compose.yml
  - path: ./apps/nextcloud/docker-compose.yml
  - path: ./apps/gitea/docker-compose.yml
```

| ✅ Vorteile | ❌ Nachteile |
|------------|------------|
| Globales `up` UND modulare Struktur | Ab Compose v2.20 verfügbar[^7] |
| Saubere Ordnerstruktur bleibt erhalten | Zirkuläre Includes möglich |
| Gute Balance aus Übersichtlichkeit und Modularität | Etwas komplexer zu debuggen |
| Einzelne Dateien bleiben selbstständig nutzbar | |

#### Modell 4: Override-Pattern für Multi-Environment

```yaml
# docker-compose.yml (Basis – wird immer geladen)
services:
  app:
    image: myapp:${VERSION:-latest}
    environment:
      - LOG_LEVEL=info
    networks:
      - app-net
  db:
    image: postgres:16-alpine
    volumes:
      - db_data:/var/lib/postgresql/data
    networks:
      - app-net
```

```yaml
# docker-compose.override.yml (Dev – automatisch geladen)
services:
  app:
    build: .                        # Statt Image: lokaler Build
    volumes:
      - .:/app                      # Quellcode live eingebunden
    environment:
      - LOG_LEVEL=debug
    ports:
      - "3000:3000"
      - "9229:9229"                  # Debug-Port
  db:
    ports:
      - "5432:5432"                  # DB direkt erreichbar (Dev only!)
```

```yaml
# docker-compose.prod.yml (Produktion – explizit angeben)
services:
  app:
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 1G
      replicas: 2
    restart: always
    logging:
      driver: "fluentd"
  db:
    # Kein Port nach außen in Produktion!
```

```bash
# Dev (override automatisch):
docker compose up -d

# Produktion:
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Nur bestimmte Services starten:
docker compose up -d app db
```

### 3.3 Empfohlene Ordnerstruktur für WSL2/Debian

```
/opt/docker/
│
├── .env                          # Globale Variablen (TZ, PUID, PGID, DOMAIN)
├── docker-compose.yml            # Optional: Master-Datei mit include
│
├── proxy/                        # Traefik oder Nginx Proxy Manager
│   ├── docker-compose.yml
│   └── secrets/
│       └── cf_api_token.txt
│
├── db-cluster/                   # Dein bestehender MariaDB + PostgreSQL Stack
│   ├── docker-compose.yml
│   └── secrets/
│       ├── mariadb_root.txt
│       └── postgres_pass.txt
│
├── monitoring/                   # Portainer, Dozzle, Uptime Kuma
│   ├── docker-compose.yml
│   └── volumes/
│
├── backups/                      # Backup-Container
│   ├── docker-compose.yml
│   └── archives/
│
└── apps/
    ├── nextcloud/
    │   ├── docker-compose.yml
    │   └── .env.local
    ├── gitea/
    │   └── docker-compose.yml
    └── vaultwarden/
        └── docker-compose.yml
```

**Globale `.env`-Datei** (`/opt/docker/.env`):
```ini
# Systemvariablen
TZ=Europe/Berlin
PUID=1000
PGID=1000

# Netzwerk
DOMAIN=intern.example.com
ACME_EMAIL=admin@example.com

# Traefik
TRAEFIK_AUTH=admin:$$2y$$10$$...  # htpasswd-Hash ($ escapen!)
```

***

## Teil 4 – Tools & Alternativen: Vollständiger Guide

### 4.1 Portainer CE – Der Industrie-Standard

Portainer ist seit 2016 das meistgenutzte Docker-Management-Tool und bietet das vollständigste Feature-Set aller verfügbaren UIs.[^8][^9]

**Stärken:**
- Vollständige Container-, Image-, Volume-, Netzwerk-Verwaltung
- Stack-Deploy via Compose-Editor
- RBAC (Role-Based Access Control) für Teams
- Multi-Environment: Docker, Docker Swarm, Kubernetes, ACI[^10]
- In-Browser-Console (exec in Container direkt im Browser)
- App-Templates mit 1-Klick-Deployments
- REST-API für Automatisierung

**Schwächen:**
- Speichert Stacks in interner Datenbank (keine nativen YAML-Dateien auf Disk)[^9]
- Höherer RAM-Verbrauch (~200–500 MB)
- Business Edition für erweiterte Features nötig
- Manche Features nur mit Portainer-Agent

```yaml
services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    ports:
      - "9443:9443"       # HTTPS Web-UI
      - "9000:9000"       # HTTP Web-UI
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - portainer_data:/data
    networks:
      - management
    labels:
      - "com.centurylinklabs.watchtower.enable=true"

volumes:
  portainer_data:

networks:
  management:
    driver: bridge
```

**Erster Aufruf:** https://localhost:9443 → Admin-Passwort setzen (muss innerhalb von 5 Min. nach Start erfolgen, sonst Timeout)

***

### 4.2 Dockge – Die moderne Portainer-Alternative

Dockge (vom Entwickler von Uptime Kuma) ist der **Compose-fokussierte Gegenentwurf zu Portainer**. Das Alleinstellungsmerkmal: Stacks bleiben als echte YAML-Dateien auf der Festplatte, kompatibel mit normalem `docker compose`-Workflow.[^11][^12][^9]

**Stärken:**
- Compose-Dateien als echte Dateien auf Disk → Git-Kompatibilität[^11]
- Interaktiver YAML-Editor mit Syntax-Highlighting
- Konvertiert `docker run`-Befehle in `compose.yml`
- Integriertes Web-Terminal pro Container
- Live-Logs direkt in der UI
- Multi-Agent (mehrere Server in einer UI)[^11]
- ~50 MB RAM-Verbrauch (sehr leichtgewichtig)

**Schwächen:**
- Kein Kubernetes / Docker Swarm
- Kein vollständiges Container-Management (kein In-Browser exec)
- Kein App-Template-System wie Portainer
- Noch junges Projekt (aktive Entwicklung, Breaking Changes möglich)

```yaml
services:
  dockge:
    image: louislam/dockge:1
    container_name: dockge
    restart: unless-stopped
    ports:
      - "5001:5001"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - dockge_data:/app/data
      - /opt/stacks:/opt/stacks     # Stacks-Verzeichnis auf dem Host
    environment:
      - DOCKGE_STACKS_DIR=/opt/stacks

volumes:
  dockge_data:
```

**Empfehlung:** Ideal für Homelab und Solo-Entwickler, die ihren Compose-Workflow behalten wollen. Als leichtgewichtige Alternative zu Portainer oder ergänzend dazu.

***

### 4.3 Yacht – Der Template-Spezialist

Yacht ist eine Vue.js-basierte UI mit Fokus auf **1-Klick-Deployments via Templates**. Es ist Portainer-Template-kompatibel und richtet sich an Einsteiger.[^13][^14]

**Stärken:**
- Sauber designte, minimalistische UI
- Template-System für schnelle App-Deployments
- Docker Compose Projekt-Editor
- Live-Metriken-Dashboard direkt auf Startseite
- Kompatibel mit Portainer-Templates[^8]
- Podman-Unterstützung (neben Docker)

**Schwächen:**
- Kein In-Browser-Terminal (kein exec)[^10]
- Nur Single-Host (Multi-Host in Development)[^10]
- Kein Kubernetes / Swarm
- Entwicklungsrhythmus unregelmäßig[^10]
- Weniger ausgereift als Portainer CE

```yaml
services:
  yacht:
    image: selfhostedpro/yacht:latest
    container_name: yacht
    restart: unless-stopped
    ports:
      - "8000:8000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - yacht_data:/config
    environment:
      - SECRET_KEY=${YACHT_SECRET_KEY:-changeme}
      - ADMIN_EMAIL=admin@local
      - DISABLE_AUTH=false         # Niemals true auf erreichbaren Hosts!
      - TZ=Europe/Berlin

volumes:
  yacht_data:
```

***

### 4.4 Umfassender Feature-Vergleich: Management-Tools

| Feature | Portainer CE | Dockge | Yacht |
|---------|:------------:|:------:|:-----:|
| **Container-Verwaltung** | ✅ Vollständig | 🟡 Basis | 🟡 Basis |
| **Docker Compose Stacks** | ✅ | ✅ (Fokus) | ✅ (Projekte) |
| **Dateien auf Disk** | ❌ (interne DB) | ✅ | ❌ |
| **Git-Kompatibilität** | 🟡 (via Git) | ✅ | ❌ |
| **Kubernetes** | ✅ | ❌ | ❌ |
| **Docker Swarm** | ✅ | ❌ | ❌ |
| **Multi-Host** | ✅ (Agents) | ✅ (Agents) | ❌ (stabil) |
| **In-Browser Terminal** | ✅ | ✅ | ❌ |
| **RBAC** | ✅ (CE: Basis) | 🟡 Basis | ❌ |
| **App-Templates** | ✅ Umfangreich | ❌ | ✅ (1-Klick) |
| **RAM-Verbrauch** | ~200–500 MB | ~50 MB | ~100 MB |
| **API** | ✅ REST-API | ❌ | ❌ |
| **docker run → compose** | ❌ | ✅ | ❌ |
| **Empfohlen für** | Teams, Prod | Homelab | Einsteiger |

***

### 4.5 Dozzle – Live Log Viewer

Dozzle ist kein vollwertiges Container-Management-Tool, sondern ein **fokussierter, leichtgewichtiger Log-Viewer** für Docker-Container im Browser.[^15]

**Alleinstellungsmerkmale:**
- Echtzeit-Streaming aller Container-Logs
- Filter, Volltextsuche, Regex-Unterstützung
- Multi-Node-Support (mehrere Docker-Hosts in einer UI)
- Unglaublich leichtgewichtig (<10 MB RAM)
- Kein persistenter Storage nötig
- Kein Schreibzugriff auf Container

```yaml
services:
  dozzle:
    image: amir20/dozzle:latest
    container_name: dozzle
    restart: unless-stopped
    ports:
      - "8888:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      - DOZZLE_LEVEL=info           # Minimales Log-Level filtern
      - DOZZLE_TAILSIZE=300         # Letzten 300 Zeilen beim Öffnen
      - DOZZLE_AUTH_PROVIDER=none   # Kein Auth (nur Homelab!)
      # Für Authentifizierung:
      # - DOZZLE_AUTH_PROVIDER=simple
      # Dann: users.yml mit Passwort-Hash einbinden
```

**Mit Authentifizierung (empfohlen bei externerm Zugriff):**
```yaml
    environment:
      - DOZZLE_AUTH_PROVIDER=simple
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./users.yml:/data/users.yml:ro
```
```yaml
# users.yml
users:
  admin:
    name: Administrator
    password: "$2y$10$..."   # bcrypt-Hash
    email: admin@local
```

***

### 4.6 Watchtower – Automatische Container-Updates

Watchtower überwacht laufende Container und **aktualisiert sie vollautomatisch**, sobald ein neues Image im Registry verfügbar ist.[^16][^17]

**Funktionsweise:** Watchtower prüft nach Zeitplan die Registry, pulled das neue Image, stoppt den alten Container und startet ihn mit identischer Konfiguration neu.

**Wichtige Konfigurationsoptionen:**
```yaml
services:
  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      # ── Zeitplan ─────────────────────────────────────
      - WATCHTOWER_SCHEDULE=0 0 4 * * 1    # Montags 04:00 Uhr (6-Feld Cron)
      # ODER: Polling-Intervall in Sekunden
      # - WATCHTOWER_POLL_INTERVAL=86400

      # ── Cleanup ──────────────────────────────────────
      - WATCHTOWER_CLEANUP=true             # Alte Images löschen

      # ── Selektive Updates ─────────────────────────────
      - WATCHTOWER_LABEL_ENABLE=true        # Nur Container mit Label updaten

      # ── Benachrichtigungen ────────────────────────────
      - WATCHTOWER_NOTIFICATIONS=gotify
      - WATCHTOWER_NOTIFICATION_GOTIFY_URL=http://gotify:80
      - WATCHTOWER_NOTIFICATION_GOTIFY_TOKEN_FILE=/run/secrets/gotify_token

      # ── Verhalten ─────────────────────────────────────
      - WATCHTOWER_INCLUDE_STOPPED=false    # Nur laufende Container
      - WATCHTOWER_REVIVE_STOPPED=false
      - WATCHTOWER_NO_STARTUP_MESSAGE=false
      - TZ=Europe/Berlin

    secrets:
      - gotify_token
```

**Container selektiv aktivieren/deaktivieren:**
```yaml
services:
  # Wird automatisch aktualisiert:
  nginx:
    image: nginx:latest
    labels:
      - "com.centurylinklabs.watchtower.enable=true"

  # Wird niemals automatisch aktualisiert:
  kritische-db:
    image: mariadb:10.11
    labels:
      - "com.centurylinklabs.watchtower.enable=false"
```

**Watchtower im Monitor-only-Modus** (Nur Benachrichtigungen, kein Update):
```yaml
    command: --run-once --monitor-only
    # ODER als Daemon:
    environment:
      - WATCHTOWER_MONITOR_ONLY=true
```

***

### 4.7 DIUN – Die sichere Watchtower-Alternative

**DIUN (Docker Image Update Notifier)** verfolgt einen anderen Ansatz: Es **benachrichtigt nur** über verfügbare Updates, führt aber niemals selbst ein Update durch.[^18][^19][^20]

| Aspekt | Watchtower | DIUN |
|--------|:----------:|:----:|
| **Automatisches Update** | ✅ | ❌ |
| **Nur Benachrichtigung** | Optional | ✅ Immer |
| **Notification-Kanäle** | ~5 (Email, Slack, etc.) | 15+ (Telegram, Discord, Matrix, ntfy, Gotify, Webhooks...) |
| **Produktionssicherheit** | ⚠️ Riskant | ✅ Sicher |
| **Ressourcenverbrauch** | ~30 MB | ~20 MB |
| **Web UI** | ❌ | ❌ |

```yaml
services:
  diun:
    image: crazymax/diun:latest
    container_name: diun
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - diun_data:/data
      - ./diun.yml:/diun.yml:ro    # Konfigurationsdatei
    environment:
      - TZ=Europe/Berlin
      - LOG_LEVEL=info

volumes:
  diun_data:
```

```yaml
# diun.yml – Konfiguration
watch:
  workers: 10
  schedule: "0 8 * * 1"      # Montags 08:00 Uhr

notif:
  telegram:
    token: "${TELEGRAM_BOT_TOKEN}"
    chatIDs:
      - "${TELEGRAM_CHAT_ID}"
  gotify:
    endpoint: "http://gotify:80"
    token: "${GOTIFY_TOKEN}"

providers:
  docker:
    watchByDefault: true       # Alle Container überwachen
```

**Empfehlung für die Praxis:**
- **Watchtower** für Entwicklungscontainer, Homelab-Services ohne Datenhaltung (nginx, heimdall)
- **DIUN** für kritische Services (Datenbanken, Vaultwarden, Authentifizierungssysteme)[^21]
- **Kombination beider** in einem gemischten Stack: DIUN für alles, Watchtower nur für explizit markierte unkritische Container[^21]

***

### 4.8 Kompletter Management-Stack für WSL2/Debian

```yaml
# /opt/docker/monitoring/docker-compose.yml
# Vollständiger Management & Monitoring Stack

services:
  # ── Portainer CE – Haupt-Management ──────────────────
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    ports:
      - "9443:9443"
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - portainer_data:/data
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
    networks:
      - management

  # ── Dozzle – Live Log Viewer ──────────────────────────
  dozzle:
    image: amir20/dozzle:latest
    container_name: dozzle
    restart: unless-stopped
    ports:
      - "8888:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      - DOZZLE_TAILSIZE=500
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
    networks:
      - management

  # ── Uptime Kuma – Service Monitoring ─────────────────
  uptime-kuma:
    image: louislam/uptime-kuma:latest
    container_name: uptime-kuma
    restart: unless-stopped
    ports:
      - "3001:3001"
    volumes:
      - uptime_kuma_data:/app/data
      - /var/run/docker.sock:/var/run/docker.sock:ro
    healthcheck:
      test: ["CMD", "node", "/app/extra/healthcheck.js"]
      interval: 30s
      timeout: 10s
      retries: 3
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
    networks:
      - management

  # ── Watchtower – Auto-Updates ─────────────────────────
  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WATCHTOWER_SCHEDULE=0 0 4 * * 1    # Montags 4 Uhr
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_LABEL_ENABLE=true        # Nur gelabelte Container
      - TZ=Europe/Berlin
    networks:
      - management

  # ── DIUN – Update-Benachrichtigungen ──────────────────
  diun:
    image: crazymax/diun:latest
    container_name: diun
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - diun_data:/data
      - ./diun.yml:/diun.yml:ro
    environment:
      - TZ=Europe/Berlin
    networks:
      - management

networks:
  management:
    driver: bridge

volumes:
  portainer_data:
  uptime_kuma_data:
  diun_data:
```

***

### 4.9 Quick-Decision-Guide: Welches Tool für welche Situation?

```
Ich brauche vollständige Container-Verwaltung mit Team-Features
→ Portainer CE

Ich verwalte primär Compose-Stacks und will YAML-Dateien auf Disk
→ Dockge

Ich bin Einsteiger und will 1-Klick-Deployments aus Templates
→ Yacht

Ich will einfach Live-Logs im Browser sehen
→ Dozzle

Ich will Container automatisch updaten (unkritische Services)
→ Watchtower (mit WATCHTOWER_LABEL_ENABLE=true)

Ich will über Updates benachrichtigt werden ohne Automatik
→ DIUN

Ich will beides: Benachrichtigungen für alles + Auto-Updates für Ausgewählte
→ DIUN + Watchtower kombiniert

Ich will Portainer ERSETZEN (leichter, compose-fokussiert)
→ Dockge (für Homelab/Solo) oder Yacht (für Einsteiger)

Mein Stack: WSL2 + Debian + bestehender DB-Cluster
→ Empfehlung: Portainer CE + Dozzle + Uptime Kuma + DIUN
```

---

## References

1. [Why use Compose? - Docker Docs](https://docs.docker.com/compose/intro/features-uses/) - Discover the benefits and typical use cases of Docker Compose for containerized application developm...

2. [compose-spec/spec.md at main · compose-spec/compose-spec](https://github.com/compose-spec/compose-spec/blob/main/spec.md) - compose-spec / **
compose-spec ** Public

3. [Do I Need Multiple Docker Compose Files for My Microservices or Just One?](https://www.youtube.com/watch?v=3qrsAt5PJwg) - ## blogize
##### Oct 21, 2024 (0:01:31)
Summary: Exploring the Pros and Cons of Using Multiple Docke...

4. [docker.github.io-1/compose/compose-file/compose-file-v3.md at master · docker/docker.github.io-1](https://github.com/docker/docker.github.io-1/blob/master/compose/compose-file/compose-file-v3.md) - This repository was archived by the owner on Apr 15, 2024. It is now read-only.

docker / **
docker....

5. [One single docker-compose.yml vs. one for each microservice?](https://www.reddit.com/r/docker/comments/9np9j6/one_single_dockercomposeyml_vs_one_for_each/) - I use a monorepo containing many microservices with a single compose file for the whole thing. Every...

6. [Should I have multiple docker-compose files? [closed] - Stack Overflow](https://stackoverflow.com/questions/62871280/should-i-have-multiple-docker-compose-files) - If all services belong to the same project You might keep them in one file. If not, split it to sepa...

7. [How to Deploy Apps with Docker Compose in 2025 - Dokploy](https://dokploy.com/blog/how-to-deploy-apps-with-docker-compose-in-2025) - Docker Compose in 2025 introduces advanced features that simplify multi-container app deployment. Ke...

8. [Yacht vs. Portainer - Docker dashboard comparison - Virtualization Howto](https://www.virtualizationhowto.com/2022/12/yacht-vs-portainer-docker-dashboard-comparison/) - Yacht vs. Portainer - Docker dashboard comparison. A look at Yacht, the Portainer alternative and wh...

9. [Portainer vs Dockge: Docker Compose Manager Comparison](https://oneuptime.com/blog/post/2026-03-20-portainer-vs-dockge-compose-manager/view) - Compare Portainer and Dockge as Docker Compose management tools for self-hosted environments, examin...

10. [Portainer Vs Yacht: Which Docker Tool Should You Use? [2026]](https://cloudzy.com/blog/portainer-vs-yacht/) - Managing Docker containers through the CLI is effective for simple setups, but it scales poorly. As ...

11. [Dockge: The Simplest Docker Compose Manager](https://selfhostedguides.com/dockge-docker-compose-manager/) - Guide to self-hosting Dockge for managing Docker Compose stacks through a clean web UI. Covers insta...

12. [Dockge: Why I switched from Portainer to this lightweight tool ...](https://bigmike.help/en/posts/dockge-why-i-switched-from-portainer-to-this-lightweight-tool-and-recomme-2f9da9/) - Why Dockge could be the ideal replacement for Portainer for self-hosting and HomeLab use cases.

13. [GitHub - Yacht-sh/Yacht: A web interface for managing docker containers with an emphasis on templating to provide 1 click deployments. Think of it like a decentralized app store for servers that anyone can make packages for.](https://github.com/Yacht-sh/Yacht) - Yacht-sh / **
Yacht ** Public
generated from hack4impact/flask-base

# Yacht-sh/Yacht

### I am curr...

14. [Yacht Docker UI: The BEST Way to Manage Docker (Portainer Alternative?)”](https://www.youtube.com/watch?v=YO1EFWKrIk0) - ## JC Laforge Tech

##### Apr 24, 2025 (0:09:15)
Stop struggling with docker run commands! In this v...

15. [Homelab - Monitoring using Uptime Kuma](https://www.youtube.com/watch?v=kKV99B0K8w0) - Setting up uptime kuma container using Portainer stack:
Docker compose file:
version: '3.3'

service...

16. [Watchtower - Update Docker Containers Automatically](https://www.youtube.com/watch?v=mSSlrRgSAP4) - ## Jim's Garage
##### Aug 05, 2024 (0:13:46)
Watchtower is a great way to update your containers. In...

17. [Watchtower -The PERFECT Docker Automation Tool?](https://www.youtube.com/watch?v=GHeZaoUpVcQ) - ## Better Stack
##### Mar 15, 2025 (0:04:22)
In this video we go through how to set up and use Watch...

18. [Watchtower vs DIUN: Docker Update Tools](https://dev.to/selfhostingsh/watchtower-vs-diun-docker-update-tools-13hj) - Should your Docker containers auto-update or just notify you? Watchtower and DIUN take fundamentally...

19. [The Ultimate Guide to Diun: Never Miss a Docker Update!](https://rantingsofasysadmin.com/the-ultimate-guide-to-diun-never-miss-a-docker-update/) - Hello again, dear readers! As Docker remains a foundational pillar of our infrastructure, the task o...

20. [Watchtower vs DIUN: Docker Update Tools - FlareStart](https://flarestart.com/article/watchtower-vs-diun-docker-update-tools-20260220) - Should your Docker containers auto-update or just notify you? Watchtower and DIUN take fundamentally...

21. [Docker Compose Magic: How to Automate All Your ...](https://dev.to/itpraktika/docker-compose-magic-how-to-automate-all-your-container-updates-with-watchtower-and-diun-1ab6) - Introduction: Why Container Automation Matters Managing Docker containers can become a...

