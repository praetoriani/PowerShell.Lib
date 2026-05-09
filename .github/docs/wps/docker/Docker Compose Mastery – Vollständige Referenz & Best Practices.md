# Docker Compose Mastery – Vollständige Referenz & Best Practices

> Umfassende Dokumentation zu Möglichkeiten, Patterns, Use Cases und Tools rund um `docker-compose.yml` – speziell für den Einsatz unter WSL2/Debian

***

## 1. Was kann `docker-compose.yml`? – Vollständiger Überblick

Eine `docker-compose.yml` ist weit mehr als ein einfaches "Container-Startskript". Sie ist eine **deklarative YAML-Spezifikation**, die die gesamte Infrastruktur einer Anwendung beschreibt und orchestriert. Mit einem einzigen `docker compose up -d` lässt sich eine vollständige Multi-Container-Umgebung hochfahren – inklusive Netzwerken, Volumes, Abhängigkeiten und Health Checks.[^1][^2]

### 1.1 Die Kernbausteine im Detail

#### `services` – Container-Definitionen

Jeder Service entspricht einem Container. Folgende Schlüssel stehen pro Service zur Verfügung:

```yaml
services:
  mein-service:
    image: nginx:alpine          # Fertiges Image aus Registry
    build:                       # ODER: Lokales Build aus Dockerfile
      context: ./app
      dockerfile: Dockerfile
    container_name: mein-nginx   # Expliziter Container-Name
    restart: unless-stopped      # always | on-failure | no
    ports:
      - "8080:80"                # Host-Port:Container-Port
    expose:
      - "9000"                   # Nur intern im Docker-Netzwerk sichtbar
    environment:
      - NODE_ENV=production
      - DB_HOST=${DB_HOST}       # Aus .env-Datei interpoliert
    env_file:
      - .env                     # Ganze .env-Datei einlesen
    volumes:
      - ./html:/usr/share/nginx/html   # Bind Mount
      - app_data:/data                 # Named Volume
    networks:
      - frontend
      - backend
    depends_on:
      db:
        condition: service_healthy    # Warten bis DB wirklich bereit
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    command: ["npm", "start"]        # Überschreibt CMD im Dockerfile
    entrypoint: ["/entrypoint.sh"]   # Überschreibt ENTRYPOINT
    user: "1000:1000"               # Kein Root-Betrieb
    working_dir: /app
    labels:
      - "traefik.enable=true"
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 512M
```

#### `volumes` – Persistente Datenspeicherung

Volumes entkoppeln Daten vom Container-Lifecycle. Daten bleiben beim `docker compose down` erhalten:[^3]

```yaml
volumes:
  db_data:                      # Named Volume (von Docker verwaltet)
  config_vol:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /mnt/my-nas/data  # Externe Bind-Mount-Variante
```

#### `networks` – Netzwerk-Isolation und Kommunikation

Custom Networks ermöglichen die gezielte Isolation von Services. Services im selben Netzwerk können einander über den **Service-Namen als DNS-Hostname** ansprechen:[^4]

```yaml
networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
  external_net:
    external: true             # Bereits existierendes Netzwerk einbinden
```

Dies ist besonders relevant, wenn du separate `docker-compose.yml`-Dateien (z.B. dein bestehender `db-cluster` und der `nginx-proxy-manager`) über ein gemeinsames externes Netzwerk verbinden willst.

#### `secrets` – Sichere Credential-Verwaltung

**Secrets** sind die sicherere Alternative zu Plaintext-Umgebungsvariablen. Sie werden als Dateien unter `/run/secrets/<secret_name>` in den Container gemountet und niemals in Umgebungsvariablen oder Container-Metadaten exponiert:[^5]

```yaml
services:
  db:
    image: mysql:latest
    environment:
      MYSQL_ROOT_PASSWORD_FILE: /run/secrets/db_root_password
    secrets:
      - db_root_password

secrets:
  db_root_password:
    file: ./secrets/db_root_password.txt   # Lokale Datei als Secret-Quelle
```

> ⚠️ **Sicherheitshinweis:** Laut einer Studie aus 2023 enthalten 8,5% aller Docker-Hub-Images exponierte Secrets (Private Keys, API-Tokens). Die korrekte Nutzung von Docker Secrets oder `.env`-Dateien (die in `.gitignore` sind) ist deshalb essenziell.[^6]

#### `configs` – Konfigurationsdateien für Container

Ähnlich wie Secrets, aber für nicht-sensible Konfigurationsdaten (z.B. nginx.conf, prometheus.yml). Die Datei wird read-only in den Container gemountet:[^7]

```yaml
configs:
  nginx_config:
    file: ./nginx.conf

services:
  proxy:
    image: nginx
    configs:
      - source: nginx_config
        target: /etc/nginx/conf.d/default.conf
```

#### `profiles` – Umgebungsspezifische Services

Mit `profiles` lassen sich Services gruppieren, die nur in bestimmten Umgebungen starten sollen:[^8]

```yaml
services:
  app:
    image: myapp
    profiles: ["production", "staging"]
  
  debug-tools:
    image: busybox
    profiles: ["development"]     # Nur in Dev-Umgebung
  
  db:
    image: postgres               # Kein Profil = immer aktiv
```

Aktivierung: `COMPOSE_PROFILES=development docker compose up`

### 1.2 Top-Level `include` – Modulare Dateien (ab Compose 2.20)

Seit Compose 2.20 können andere Compose-Dateien eingebunden werden:[^9]

```yaml
include:
  - path: ../db-cluster/docker-compose.yml
  - path: ./monitoring/docker-compose.yml

services:
  myapp:
    image: myapp:latest
    networks:
      - db-cluster_default   # Netzwerk aus eingebundener Datei
```

### 1.3 Wichtige `docker compose`-Befehle

| Befehl | Beschreibung |
|--------|-------------|
| `docker compose up -d` | Alle Services starten (detached) |
| `docker compose down` | Services stoppen und Netzwerke entfernen |
| `docker compose down -v` | Inkl. Löschen der Volumes |
| `docker compose ps` | Status aller Services |
| `docker compose logs -f [service]` | Live-Logs eines Services |
| `docker compose exec [service] bash` | Shell in laufenden Container |
| `docker compose pull` | Alle Images aktualisieren |
| `docker compose build` | Images neu bauen |
| `docker compose restart [service]` | Einzelnen Service neu starten |
| `docker compose up --watch` | Live-Reload bei Dateiänderungen (Dev) |
| `docker compose -f base.yml -f override.yml up` | Mehrere Dateien zusammenführen |
| `docker compose config` | Zusammengeführte Konfiguration ausgeben |

### 1.4 Override-Dateien für Multi-Environment-Setup

Compose liest automatisch `docker-compose.yml` + `docker-compose.override.yml` zusammen. Best Practice ist ein dreistufiges Setup:[^10]

```
docker-compose.yml           # Basis-Konfiguration (gemeinsam)
docker-compose.override.yml  # Lokale Dev-Overrides (automatisch geladen)
docker-compose.prod.yml      # Produktionskonfiguration
docker-compose.dev.yml       # Explizite Dev-Overrides
```

```bash
# Produktion:
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Entwicklung (override automatisch):
docker compose up -d
```

***

## 2. Mehrere Anwendungen in einer `docker-compose.yml`

### 2.1 Wie es technisch funktioniert

Mehrere vollständig unabhängige Applikationen lassen sich problemlos in einer einzigen `docker-compose.yml` definieren. Docker Compose erstellt automatisch ein gemeinsames Projekt-Netzwerk, in dem alle Services per Service-Name kommunizieren können:[^11][^1]

```yaml
services:
  # ── Anwendung 1: WordPress ──────────────────────────
  wordpress:
    image: wordpress:latest
    ports:
      - "8080:80"
    environment:
      WORDPRESS_DB_HOST: wp-db:3306
      WORDPRESS_DB_NAME: wordpress
    networks:
      - wp_net
    depends_on:
      wp-db:
        condition: service_healthy

  wp-db:
    image: mariadb:10.11
    environment:
      MYSQL_DATABASE: wordpress
      MYSQL_ROOT_PASSWORD_FILE: /run/secrets/wp_db_pass
    volumes:
      - wp_db_data:/var/lib/mysql
    networks:
      - wp_net
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect"]
      interval: 10s
      retries: 5
    secrets:
      - wp_db_pass

  # ── Anwendung 2: Gitea (Git-Server) ─────────────────
  gitea:
    image: gitea/gitea:latest
    ports:
      - "3000:3000"
      - "2222:22"
    volumes:
      - gitea_data:/data
    networks:
      - gitea_net
    depends_on:
      - gitea-db

  gitea-db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: gitea
      POSTGRES_USER: gitea
      POSTGRES_PASSWORD_FILE: /run/secrets/gitea_db_pass
    volumes:
      - gitea_db_data:/var/lib/postgresql/data
    networks:
      - gitea_net
    secrets:
      - gitea_db_pass

networks:
  wp_net:
    driver: bridge
  gitea_net:
    driver: bridge   # Getrennte Netzwerke = keine Cross-App-Kommunikation

volumes:
  wp_db_data:
  gitea_data:
  gitea_db_data:

secrets:
  wp_db_pass:
    file: ./secrets/wp_db_pass.txt
  gitea_db_pass:
    file: ./secrets/gitea_db_pass.txt
```

> **Wichtig:** Durch separate benannte Netzwerke sind die beiden Applikationen vollständig voneinander isoliert. Nur Services, die dasselbe Netzwerk teilen, können miteinander kommunizieren.

### 2.2 Vor- und Nachteile: Eine Datei vs. mehrere Dateien

#### Eine gemeinsame `docker-compose.yml`

| Merkmal | Detail |
|---------|--------|
| ✅ Einfaches Management | `docker compose up/down` startet/stoppt alles auf einmal |
| ✅ Übersichtlichkeit | Gesamtarchitektur auf einen Blick sichtbar |
| ✅ Einheitliche Netzwerkverwaltung | Services können gezielt vernetzt werden |
| ✅ Einfache `.env`-Verwaltung | Eine zentrale `.env`-Datei für alle[^12] |
| ✅ Atomare Deployments | Alle Services auf konsistentem Stand |
| ❌ Wächst schnell unübersichtlich | Bei 10+ Services wird die Datei schwer wartbar |
| ❌ Alles-oder-nichts-Problem | `docker compose down` stoppt alle Anwendungen |
| ❌ Unabhängige Updates erschwert | Ein Update erfordert das Einlesen der gesamten Datei |
| ❌ Team-Konflikte | Mehrere Entwickler arbeiten an derselben Datei[^13] |

#### Separate `docker-compose.yml` pro Anwendung

| Merkmal | Detail |
|---------|--------|
| ✅ Modulare Struktur | Jede App in eigenem Ordner mit eigener Datei[^14] |
| ✅ Unabhängige Lifecycle-Kontrolle | Apps einzeln starten/stoppen/aktualisieren |
| ✅ Bessere Wartbarkeit | Kleinere, spezifischere Dateien |
| ✅ Team-freundlich | Verschiedene Teams arbeiten unabhängig |
| ✅ Einfacheres Debugging | Klar abgegrenzte Scope per Datei |
| ❌ Netzwerk-Kommunikation aufwändiger | Externe Netzwerke notwendig für Cross-App-Kommunikation |
| ❌ Mehrere `.env`-Dateien | Duplikation von gemeinsamen Variablen (TZ, DOMAIN, etc.) |
| ❌ Mehr Befehle | Kein einzelnes `up` für alles |

### 2.3 Der empfohlene Mittelweg: Projektordner + `include`

```
/opt/docker/
├── .env                          # Globale Variablen (TZ, PUID, PGID)
├── docker-compose.yml            # Master-Datei mit include-Direktiven
├── db-cluster/
│   └── docker-compose.yml        # MariaDB + PostgreSQL (bereits vorhanden)
├── proxy/
│   └── docker-compose.yml        # Nginx Proxy Manager
├── monitoring/
│   └── docker-compose.yml        # Portainer + Dozzle
└── apps/
    ├── wordpress/
    │   └── docker-compose.yml
    └── gitea/
        └── docker-compose.yml
```

Die Master-Datei `/opt/docker/docker-compose.yml`:
```yaml
include:
  - path: ./db-cluster/docker-compose.yml
  - path: ./proxy/docker-compose.yml
  - path: ./monitoring/docker-compose.yml
```

So kannst du alles mit einem Befehl starten UND trotzdem modular bleiben.[^9]

### 2.4 Was macht Sinn zusammen vs. getrennt?

**Zusammen in eine Datei** (gleiche funktionale Einheit):
- App-Backend + App-Datenbank + App-Cache (z.B. API + PostgreSQL + Redis)
- Monitoring-Stack (Portainer + Dozzle + Uptime Kuma)
- Proxy + zugehörige Datenbank (Nginx Proxy Manager + MariaDB ← dein Setup!)

**Getrennt in eigene Dateien** (unabhängige Anwendungen):
- Dein `db-cluster` (MariaDB + PostgreSQL) separat vom Proxy
- Verschiedene Self-hosted Apps (Gitea, Nextcloud, Vaultwarden)
- Monitoring-Stack separat von den überwachten Services

***

## 3. Use Cases jenseits von Web-Apps

`docker-compose.yml` ist ein universelles Werkzeug weit über Web-Applikationen hinaus. Hier sind die wichtigsten Anwendungsgebiete:[^15]

### 3.1 Komplettes Monitoring-Infrastruktur

Ein vollständiger Observability-Stack mit Prometheus, Grafana, Node Exporter und Alertmanager:[^16]

```yaml
services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    ports:
      - "9090:9090"
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    volumes:
      - grafana_data:/var/lib/grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD_FILE=/run/secrets/grafana_pass
    secrets:
      - grafana_pass
    networks:
      - monitoring

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    expose:
      - 9100
    networks:
      - monitoring

  uptime-kuma:
    image: louislam/uptime-kuma:latest
    container_name: uptime-kuma
    restart: unless-stopped
    volumes:
      - uptime_kuma_data:/app/data
      - /var/run/docker.sock:/var/run/docker.sock:ro
    ports:
      - "3001:3001"
    networks:
      - monitoring

networks:
  monitoring:
    driver: bridge

volumes:
  prometheus_data:
  grafana_data:
  uptime_kuma_data:

secrets:
  grafana_pass:
    file: ./secrets/grafana_pass.txt
```

### 3.2 CI/CD und Test-Environments

Docker Compose wird extensiv für automatisierte Tests und Integration-Testing eingesetzt:[^17]

```yaml
services:
  test-db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: testpass
      POSTGRES_DB: testdb
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      retries: 5

  integration-tests:
    build: ./tests
    depends_on:
      test-db:
        condition: service_healthy
    command: ["pytest", "-v", "--tb=short"]
    environment:
      DB_URL: postgresql://postgres:testpass@test-db:5432/testdb
```

Ausführung einmalig, dann Cleanup: `docker compose run --rm integration-tests`

### 3.3 Task Runner / Build-Tooling

Compose als universeller Task-Runner für Linting, Testing, DB-Migrationen:[^15]

```yaml
services:
  # Nur bei Bedarf gestartet, nicht dauerhaft laufend
  linter:
    image: node:20-alpine
    working_dir: /app
    volumes:
      - .:/app
    command: ["npx", "eslint", "src/"]
    profiles: ["tools"]

  migrations:
    image: flyway/flyway:latest
    volumes:
      - ./migrations:/flyway/sql
    environment:
      FLYWAY_URL: jdbc:postgresql://db:5432/mydb
    depends_on:
      db:
        condition: service_healthy
    profiles: ["tools"]
    command: migrate
```

```bash
docker compose run --rm linter
docker compose run --rm migrations
```

### 3.4 Backup-Lösungen

```yaml
services:
  backup:
    image: offen/docker-volume-backup:latest
    container_name: backup
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - db_data:/backup/db_data:ro
      - ./backups:/archive
    environment:
      BACKUP_CRON_EXPRESSION: "0 2 * * *"   # Täglich 2 Uhr nachts
      BACKUP_RETENTION_DAYS: "7"
      BACKUP_FILENAME: "backup-%Y-%m-%dT%H-%M-%S.tar.gz"
```

### 3.5 Heimnetzwerk-Infrastruktur (Homelab)

```yaml
services:
  adguard:
    image: adguard/adguardhome:latest    # DNS-Blocker / Ad-Blocker
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "3000:3000"
    volumes:
      - adguard_work:/opt/adguardhome/work
      - adguard_conf:/opt/adguardhome/conf

  vaultwarden:
    image: vaultwarden/server:latest     # Passwort-Manager (Bitwarden-kompatibel)
    ports:
      - "8080:80"
    volumes:
      - vaultwarden_data:/data
    environment:
      - WEBSOCKET_ENABLED=true
      - SIGNUPS_ALLOWED=false

  nextcloud:
    image: nextcloud:latest              # Cloud-Speicher
    ports:
      - "8443:443"
    volumes:
      - nextcloud_data:/var/www/html
    depends_on:
      - nextcloud-db

  nextcloud-db:
    image: mariadb:10.11
    volumes:
      - nextcloud_db:/var/lib/mysql
    environment:
      MYSQL_DATABASE: nextcloud
      MYSQL_USER: nextcloud
```

### 3.6 Entwicklungsumgebungen (Dev Containers)

Compose reproduziert die gesamte Entwicklungsumgebung zuverlässig – kein "works on my machine":[^18]

```yaml
services:
  app:
    build:
      context: .
      target: development             # Multi-Stage: Dev-Stage nutzen
    volumes:
      - .:/app                        # Quellcode live eingebunden
      - /app/node_modules             # node_modules NICHT überschreiben
    ports:
      - "3000:3000"                   # Dev-Server
      - "9229:9229"                   # Node Debugger
    environment:
      - NODE_ENV=development
    command: npm run dev              # Hot-Reload

  mailcatcher:
    image: sj26/mailcatcher          # Fängt alle gesendeten E-Mails ab
    ports:
      - "1080:1080"                  # Web-UI für E-Mails
    profiles: ["development"]
```

### 3.7 Machine Learning / Data Science

Docker Compose wird auch in der Wissenschaft für reproduzierbare Experiment-Umgebungen eingesetzt:[^19]

```yaml
services:
  jupyter:
    image: jupyter/tensorflow-notebook:latest
    ports:
      - "8888:8888"
    volumes:
      - ./notebooks:/home/jovyan/work
    environment:
      - JUPYTER_ENABLE_LAB=yes
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]    # GPU-Zugriff für CUDA

  mlflow:
    image: ghcr.io/mlflow/mlflow:latest
    ports:
      - "5000:5000"
    volumes:
      - mlflow_data:/mlflow
    command: mlflow server --host 0.0.0.0
```

***

## 4. Portainer und Dozzle in einer `docker-compose.yml`

### 4.1 Portainer + Dozzle – Vollständiges Beispiel

Ja, Portainer und Dozzle lassen sich hervorragend in einer gemeinsamen `docker-compose.yml` definieren. Beide Tools benötigen Zugriff auf den Docker-Socket:[^20][^21]

```yaml
# /opt/docker/monitoring/docker-compose.yml
# Monitoring & Management Stack für WSL2/Debian

services:
  # ── Portainer CE – Docker Management UI ─────────────
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    ports:
      - "9443:9443"       # HTTPS Web-UI
      - "9000:9000"       # HTTP Web-UI (optional)
      - "8000:8000"       # Edge Agent Tunnel (optional)
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - portainer_data:/data
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
      - DOZZLE_LEVEL=info
      - DOZZLE_TAILSIZE=300          # Letzte 300 Log-Zeilen beim Öffnen
    networks:
      - management

networks:
  management:
    driver: bridge

volumes:
  portainer_data:
```

**Starten:**
```bash
cd /opt/docker/monitoring
docker compose up -d
```

- **Portainer:** https://localhost:9443 (Zertifikat-Warnung beim ersten Aufruf ignorieren/akzeptieren)
- **Dozzle:** http://localhost:8888

> ⚠️ **Sicherheitshinweis für WSL2:** Da du unter Windows/WSL2 arbeitest, ist `localhost` in beiden Systemen zugänglich. Stelle sicher, dass Port `9443` und `8888` nicht nach außen exponiert sind, solange du kein HTTPS mit gültigem Zertifikat hast.

### 4.2 Erweiterter Stack: Portainer + Dozzle + Uptime Kuma

```yaml
services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    ports:
      - "9443:9443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - portainer_data:/data
    networks:
      - management

  dozzle:
    image: amir20/dozzle:latest
    container_name: dozzle
    restart: unless-stopped
    ports:
      - "8888:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - management

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
    networks:
      - management

networks:
  management:
    driver: bridge

volumes:
  portainer_data:
  uptime_kuma_data:
```

### 4.3 Weitere empfehlenswerte Docker-Management-Tools

#### Feature-Matrix der wichtigsten Tools

| Tool | Container Mgmt | Stack-Deploy | Monitoring | RBAC | Multi-Node | Kosten |
|------|:--------------:|:------------:|:----------:|:----:|:----------:|--------|
| **Portainer CE** | ✅ | ✅ | ✅ | ✅ | ✅ | Kostenlos (limitiert)[^22] |
| **Dockge** | ✅ | ✅ | ✅ | ✅ | ✅ | Vollständig kostenlos[^23] |
| **Yacht** | ✅ | ✅ | ✅ | ❌ | ❌ | Vollständig kostenlos[^23] |
| **Kompose UI** | ✅ | ✅ | ❌ | ✅ | ✅ | Vollständig kostenlos[^23] |
| **Lazydocker** | ✅ | ❌ | ✅ | ❌ | ❌ | Vollständig kostenlos[^23] |
| **Watchtower** | Auto-Update | ❌ | ❌ | ❌ | ❌ | Kostenlos |
| **Dozzle** | ❌ | ❌ | Logs only | ❌ | ✅ | Kostenlos |

#### Dockge – Die schlanke Portainer-Alternative

Dockge ist vom Entwickler von Uptime Kuma und positioniert sich als leichtgewichtige, compose-fokussierte Alternative zu Portainer. Im Gegensatz zu Portainer "entführt" Dockge deine Compose-Dateien nicht in eine interne Datenbank – sie bleiben als gewöhnliche YAML-Dateien auf der Festplatte:[^24][^21]

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
      - /opt/stacks:/opt/stacks     # Verzeichnis für alle deine Stacks
    environment:
      - DOCKGE_STACKS_DIR=/opt/stacks

volumes:
  dockge_data:
```

**Stärken von Dockge:**
- Interaktiver YAML-Editor mit Syntax-Highlighting
- Echtzeit-Logs und integriertes Web-Terminal pro Container
- Konvertiert `docker run`-Befehle automatisch in `compose.yml`[^24]
- Nur ~50 MB RAM-Verbrauch
- Multi-Agent-Support (mehrere Docker-Hosts in einem UI)[^25]
- Dateien bleiben im Standard-Format, kompatibel mit normalen `docker compose`-Befehlen[^26]

#### Watchtower – Automatisches Container-Update

Watchtower überwacht laufende Container und aktualisiert sie automatisch, wenn neue Images verfügbar sind:

```yaml
services:
  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WATCHTOWER_SCHEDULE=0 0 4 * * *    # Täglich 4 Uhr
      - WATCHTOWER_CLEANUP=true             # Alte Images löschen
      - WATCHTOWER_INCLUDE_STOPPED=false    # Nur laufende Container
      - WATCHTOWER_NOTIFICATIONS=gotify    # Benachrichtigungen
```

> **Hinweis:** Für Produktionsumgebungen ist automatisches Auto-Update umstritten. Im Homelab/Dev-Bereich ist es jedoch sehr praktisch.[^27]

#### Uptime Kuma – Self-Hosted Monitoring

Uptime Kuma ist ein elegantes Monitoring-Tool für Websites, APIs, Ports und mehr. Es unterstützt HTTP(S)-, TCP-, Ping-, DNS- und Docker-Container-Monitoring sowie viele Benachrichtigungskanäle (Telegram, Discord, Slack, E-Mail, etc.):[^28]

```yaml
services:
  uptime-kuma:
    image: louislam/uptime-kuma:latest
    container_name: uptime-kuma
    restart: unless-stopped
    ports:
      - "3001:3001"
    volumes:
      - uptime_kuma_data:/app/data
      - /var/run/docker.sock:/var/run/docker.sock:ro
```

#### Lazydocker – Terminal-UI (TUI)

Für Terminal-Liebhaber: Lazydocker ist eine TUI (Terminal User Interface) zur Docker-Verwaltung ohne Browser:

```bash
# Installation in WSL2/Debian
curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
```

Oder als Container:
```yaml
services:
  lazydocker:
    image: lazyteam/lazydocker
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /root/.config/lazydocker:/root/.config/lazydocker
    profiles: ["tools"]    # Nur bei Bedarf starten
```

### 4.4 Empfohlene Tool-Kombination für deinen WSL2/Debian-Setup

Für deinen bestehenden Stack (MariaDB-Cluster, PostgreSQL, Nginx Proxy Manager) empfiehlt sich folgende Kombination:

| Rolle | Tool | Begründung |
|-------|------|-----------|
| **Container-Verwaltung** | Portainer CE | Vollfeatures, Stack-Deploy, Templates |
| **Log-Monitoring** | Dozzle | Leichtgewichtig, live Logs im Browser |
| **Uptime-Monitoring** | Uptime Kuma | Überwacht NPM, Datenbanken, APIs |
| **Auto-Updates** | Watchtower | Hält Images aktuell (optional) |
| **Compose-Editor** | Dockge (alternativ) | Wenn Portainer zu schwergewichtig wirkt |

***

## 5. Wichtige Best Practices auf einen Blick

### 5.1 Sicherheit

- **Keine Klartext-Passwörter** in der `docker-compose.yml` – immer `.env` oder Docker Secrets verwenden[^3][^5]
- **`.env`-Datei in `.gitignore`** eintragen – eine `.env.example` mit leerem Inhalt als Vorlage committen[^12]
- **Non-Root-User** für Container: `user: "1000:1000"` in der Service-Definition
- **Read-Only Mounts** für den Docker-Socket: `/var/run/docker.sock:/var/run/docker.sock:ro`
- **Netzwerk-Segmentierung**: Datenbanken nie direkt ins Frontend-Netzwerk, sondern nur ins Backend-Netzwerk[^29]

### 5.2 Stabilität & Zuverlässigkeit

- **Health Checks** für alle Services definieren, die von anderen Services abhängen[^30]
- **`depends_on` mit `condition: service_healthy`** statt nur `condition: service_started`[^31]
- **`restart: unless-stopped`** für alle dauerhaft laufenden Services
- **`start_period`** beim Healthcheck für Datenbanken, die Initialisierungszeit brauchen[^30]

### 5.3 Performance & Ressourcen

- **Resource Limits** setzen – verhindert, dass ein Container die gesamte WSL2-Umgebung lahmlegt:[^32]
  ```yaml
  deploy:
    resources:
      limits:
        cpus: "0.5"
        memory: 512M
      reservations:
        memory: 256M
  ```
- **Named Volumes** statt Bind Mounts für Produktionsdaten – bessere Performance unter WSL2[^3]
- **Log-Rotation** konfigurieren: `max-size: "10m"` verhindert volle Festplatten

### 5.4 Strukturierung & Maintainability

- **Alphabetische Sortierung** der Services und Environment-Variablen[^33]
- **Explizite `container_name`** vergeben – vermeidet kryptische Auto-Namen[^33]
- **`.env.example`** pflegen mit allen benötigten Keys, aber ohne echte Werte[^12]
- **`version`-Feld weglassen** – ab Docker Compose v2 (2025+) nicht mehr nötig und erzeugt Warnings[^29]

### 5.5 WSL2-spezifische Hinweise

- **Docker-Socket-Pfad** unter WSL2/Debian ist `/var/run/docker.sock` (nicht Windows-Pfad)
- **Systemd in WSL2** aktivieren für Auto-Start: in `/etc/wsl.conf` eintragen: `[boot]` → `systemd=true`[^34]
- **Volume-Performance**: Für häufig geschriebene Daten (DB-Files) Native Volumes nutzen, nicht Windows-Dateisystem (`/mnt/c/`)
- **Portainer auf WSL2**: Zugriff über `localhost:9443` sowohl aus Windows-Browser als auch aus WSL2[^35]

***

## 6. Vollständiges Beispiel: Dein erweiterter Stack

Basierend auf deinem bestehenden Setup (MariaDB-Cluster, PostgreSQL, NPM) ein vollständiges Beispiel für einen erweiterten Management-Stack:

```yaml
# /opt/docker/management/docker-compose.yml
# Management & Monitoring Stack

services:
  # ── Portainer CE ──────────────────────────────────────
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
    networks:
      - management
    labels:
      - "com.docker.compose.project=management"

  # ── Dozzle (Log-Viewer) ───────────────────────────────
  dozzle:
    image: amir20/dozzle:latest
    container_name: dozzle
    restart: unless-stopped
    ports:
      - "8888:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      - DOZZLE_LEVEL=info
      - DOZZLE_TAILSIZE=500
    networks:
      - management

  # ── Uptime Kuma (Service-Monitoring) ─────────────────
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
    networks:
      - management

  # ── Watchtower (Auto-Updates) ─────────────────────────
  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WATCHTOWER_SCHEDULE=0 0 4 * * *
      - WATCHTOWER_CLEANUP=true
      - TZ=Europe/Berlin
    networks:
      - management

networks:
  management:
    driver: bridge

volumes:
  portainer_data:
  uptime_kuma_data:
```

**Zugriff nach `docker compose up -d`:**
- 🖥️ **Portainer:** https://localhost:9443
- 📋 **Dozzle:** http://localhost:8888
- 📡 **Uptime Kuma:** http://localhost:3001

---

## References

1. [Docker Compose – Multi-Container-Anwendungen einfach verwalten](https://tutorialwelt.de/1286/docker-tutorial-6-docker-compose-multi-container-anwendungen-einfach-verwalten.htm) - Was ist Docker Compose? Docker Compose ist ein Tool zur Definition und Verwaltung von Multi-Containe...

2. [Why use Compose? - Docker Docs](https://docs.docker.com/compose/intro/features-uses/) - Discover the benefits and typical use cases of Docker Compose for containerized application developm...

3. [10 Best Practices for Writing Maintainable Docker Compose Files](https://dev.to/wallacefreitas/10-best-practices-for-writing-maintainable-docker-compose-files-4ca2) - 1. Use Versioning Properly · 2. Keep Services Modular and Purpose-Driven · 3. Use Named Volumes for ...

4. [docker.github.io-1/compose/compose-file/compose-versioning.md at master · docker/docker.github.io-1](https://github.com/docker/docker.github.io-1/blob/master/compose/compose-file/compose-versioning.md) - This repository was archived by the owner on Apr 15, 2024. It is now read-only.

docker / **
docker....

5. [Manage secrets securely in Docker Compose](https://docs.docker.com/compose/how-tos/use-secrets/) - Getting a secret into a container is a two-step process. First, define the secret using the top-leve...

6. [Secrets Revealed in Container Images: An Internet-wide Study on
  Occurrence and Impact](https://arxiv.org/pdf/2307.03958.pdf) - ...images that include private keys or API
secrets-either by mistake or out of negligence. This leak...

7. [Docker Compose Tutorial for Beginners (Networks - Volumes - Secrets - Postgres - Letsencrypt)](https://www.youtube.com/watch?v=YMBT1NguJJw) - ## Anton Putra
##### Jul 25, 2024 (1:12:25)
👨‍💼📈 Mentorship/On-the-Job Support/Consulting - https://...

8. [Allow depends_on to be optional to use profiles to control ...](https://github.com/compose-spec/compose-spec/issues/274) - compose-spec / **
compose-spec ** Public

# Allow depends_on to be optional to use profiles to contr...

9. [best practices for multiple docker compose files? : r/selfhosted - Reddit](https://www.reddit.com/r/selfhosted/comments/18sfkc7/best_practices_for_multiple_docker_compose_files/) - I'm trying to redo with a separate compose file for each "app". If an app depends on multiple micros...

10. [docs/content/compose/multiple-compose-files/merge.md at 71c6d2d88a0086f36e21705fdf35aa08322d8867 · docker/docs](https://github.com/docker/docs/blob/71c6d2d88a0086f36e21705fdf35aa08322d8867/content/compose/multiple-compose-files/merge.md) - docker / **
docs ** Public

##

# merge.md

## Latest commit

 

## History
History

278 lines (217 ...

11. [Entwicklung vereinfachen mit Docker App und Docker-Compose: Ein Leitfaden zum Kombinieren von Diens](https://www.youtube.com/watch?v=ylFB4aoDJYs) - ## vlogize
##### Jan 10, 2026 (0:01:54)

Erfahren Sie, wie Sie Ihren Entwicklungs-Workflow optimiere...

12. [Day 11: Advanced Docker Compose](https://dev.to/code42cate/day-11-advanced-docker-compose-32no) - This is a crosspost from adventofdocker.com Welcome to day 12 of Advent of Docker! Yesterday we...

13. [Do I Need Multiple Docker Compose Files for My Microservices or Just One?](https://www.youtube.com/watch?v=3qrsAt5PJwg) - ## blogize
##### Oct 21, 2024 (0:01:31)
Summary: Exploring the Pros and Cons of Using Multiple Docke...

14. [docker-compose-file-best-practices-for-large-scale-orchestration](https://blog.poespas.me/posts/2025/02/26/docker-compose-file-best-practices-large-scale-orchestration/) - Introduction Docker Compose has become an indispensable tool for modern software development and dep...

15. [Beyond Services: Using Docker Compose as a Task Runner · gitops-ci-cd · Discussion #1](https://github.com/orgs/gitops-ci-cd/discussions/1) - # GitOps CI/CD

# Beyond Services: Using Docker Compose as a Task Runner #1

Beyond Services: Using ...

16. [Deploying Monitoring Tools: Prometheus, Alertmanager, Grafana ...](https://blog.devops.dev/deploying-monitoring-tools-prometheus-alertmanager-grafana-node-exporter-and-uptime-kuma-with-b596f2390aa7) - In this guide, we will explore how to deploy a complete monitoring stack using Docker Compose. The t...

17. [Docker Compose Strategy](https://gist.github.com/slominskir/a7da801e8259f5974c978f9c3091d52c) - # Docker Compose Strategy

This document describes how to leverage docker compose for multiple use c...

18. [Why Use Docker: Real-life Use Cases, Examples, and Takeaways](https://www.oursky.com/blogs/why-use-docker-real-life-use-cases-examples-and-takeaways) - In Oursky, we use docker-compose for development, testing, and production. The Dockerfile and docker...

19. [Studying the Practices of Deploying Machine Learning Projects on Docker](https://arxiv.org/pdf/2206.00699.pdf) - Docker is a containerization service that allows for convenient deployment of
websites, databases, a...

20. [docker-portainer/install-dozzle-on-docker/docker-compose.yml at main](https://git.viper.ipv64.net/M_Viper/docker-portainer/src/branch/main/install-dozzle-on-docker/docker-compose.yml?display=source) - docker-portainer

21. [Dockge: The Simplest Docker Compose Manager - Selfhosted Guides](https://www.selfhostedguides.com/dockge-docker-compose-manager/) - Guide to self-hosting Dockge for managing Docker Compose stacks through a clean web UI. Covers insta...

22. [Portainer vs Podman: Best Container Management Tool in 2025?](https://www.youtube.com/watch?v=K3DYDC-2Ay8) - ## Savage Reviews
##### Jun 19, 2025 (0:01:46)
🤑 Best Deals on Amazon: https://amzn.to/3JPwht2

👉 🏆 ...

23. [Top Portainer Alternatives for Docker in 2026 | Better Stack Community](https://betterstack.com/community/comparisons/docker-ui-alternative/) - Looking for a Portainer alternative in 2026? Explore top free Docker management UIs like Dockge, Kom...

24. [GitHub - louislam/dockge: A fancy, easy-to-use and reactive self-hosted docker compose.yaml stack-oriented manager](http://github.com/louislam/dockge) - louislam / **
dockge ** Public

- louislam

  louislam

  opencollective.com/**uptime-kuma**

# loui...

25. [dockge/README.md at master · louislam/dockge](https://github.com/louislam/dockge/blob/master/README.md) - louislam / **
dockge ** Public

##

# README.md

## Latest commit

 

## History
History

207 lines ...

26. [Configuring Containers in...](https://www.wundertech.net/dockge-docker-manager/) - Learn how to manage your Docker containers using Dockge, a beautiful, self-hosted, Docker Compose ma...

27. [I haven't heard of using docker compose for production development ...](https://news.ycombinator.com/item?id=27360484)

28. [GitHub - azita-abdollahi/uptime-kuma: Deploy uptime-kuma(easy-to-use self-hosted monitoring tool) and integrate with prometheus and grafana in Docker](https://github.com/azita-abdollahi/uptime-kuma) - azita-abdollahi / **
uptime-kuma ** Public

29. [How to Deploy Apps with Docker Compose in 2025 - Dokploy](https://dokploy.com/blog/how-to-deploy-apps-with-docker-compose-in-2025) - Docker Compose in 2025 introduces advanced features that simplify multi-container app deployment. Ke...

30. [Docker Compose Health Checks and Startup Order Done ...](https://docker.recipes/blog/docker-compose-healthchecks-depends-on) - How to use health checks and depends_on conditions to ensure your services start in the correct orde...

31. [Complete Example: Full Stack...](https://oneuptime.com/blog/post/2026-01-16-docker-compose-depends-on-healthcheck/view) - Learn how to properly configure service dependencies in Docker Compose using depends_on with health ...

32. [Best Practices Around Production Ready Web Apps with Docker Compose](https://www.youtube.com/watch?v=T--X3v2pwtU) - This is the director's cut of my DockerCon 21 talk which has 4 extra minutes of content.  A blog pos...

33. [Best Practice - "Coding Convention" for Docker-Compose](https://gist.github.com/ccdle12/6095c492af084f67a0b730dd01d75865) - # Docker Compose

This file is documenting best practices when it comes to using docker-compose file...

34. [How to Install Portainer on WSL2 with Ubuntu - Part 2 - OneUptime](https://oneuptime.com/blog/post/2026-03-20-portainer-wsl2/view) - How to Install Portainer on WSL2 with Ubuntu - Part 2 · Step 1: Enable WSL2 · Step 2: Install Docker...

35. [portainer-docs/start/install-ce/server/docker/wsl.md at 2.21 · portainer/portainer-docs](https://github.com/portainer/portainer-docs/blob/2.21/start/install-ce/server/docker/wsl.md) - portainer / **
portainer-docs ** Public

##

# wsl.md

## Latest commit

 

## History
History

71 l...

