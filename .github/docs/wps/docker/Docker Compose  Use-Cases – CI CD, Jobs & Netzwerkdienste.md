# Docker Compose: Use-Cases jenseits von Web-Apps – CI/CD, Jobs & Netzwerkdienste

> Tiefgehende technische Dokumentation für fortgeschrittene `docker-compose.yml`-Szenarien: Continuous Integration, Scheduled Jobs, One-Off-Tasks und vollständige Netzwerkinfrastruktur – speziell für WSL2/Debian-Umgebungen.

***

## Teil A – CI/CD mit Docker Compose

### Grundkonzept: Compose als CI-Fundament

Docker Compose ist nicht nur ein Deployment-Werkzeug, sondern ein vollwertiges CI/CD-Fundament. Das Kernprinzip ist simpel: Eine `docker-compose.yml` beschreibt dieselbe Umgebung sowohl lokal auf dem Entwicklerrechner als auch in der CI-Pipeline – **keine Abweichungen, kein "works on my machine"**.[^1][^2]

Die typischen CI-Rollen von Compose:
1. **Test-Infrastruktur aufspannen** – Datenbank, Cache, Messaging-Broker
2. **Integration Tests ausführen** – Testsuite gegen echte Services
3. **Build-Artefakte erzeugen** – Images bauen und taggen
4. **Self-hosted CI-Runner betreiben** – GitLab Runner, Drone, Gitea Actions als Container

***

### A.1 Integrationstests mit realen Abhängigkeiten

#### Das Pattern: Test-Container + Service-Container

Das klassische CI-Compose-Pattern trennt den **Test-Container** sauber von den **Service-Containern**. Der Test-Container startet erst, wenn alle Abhängigkeiten wirklich bereit sind (`condition: service_healthy`):[^3]

```yaml
# docker-compose.ci.yml
# Nur für CI/CD-Pipelines, wird nicht produktiv betrieben

services:
  # ── Testdatenbank ────────────────────────────────────
  test-db:
    image: postgres:16-alpine
    container_name: test-db
    environment:
      POSTGRES_DB: testdb
      POSTGRES_USER: testuser
      POSTGRES_PASSWORD: testpass     # In CI kein Secret nötig, nur ephemer
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U testuser -d testdb"]
      interval: 5s
      timeout: 5s
      retries: 10
      start_period: 10s
    tmpfs:
      - /var/lib/postgresql/data      # In RAM → viel schneller in CI
    networks:
      - ci-net

  # ── Redis als Cache/Queue ────────────────────────────
  test-redis:
    image: redis:7-alpine
    container_name: test-redis
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      retries: 5
    networks:
      - ci-net

  # ── Eigene App für Tests bauen ───────────────────────
  app-under-test:
    build:
      context: .
      target: development             # Multi-Stage: nur Dev-Layer
    depends_on:
      test-db:
        condition: service_healthy
      test-redis:
        condition: service_healthy
    environment:
      - DATABASE_URL=postgresql://testuser:testpass@test-db:5432/testdb
      - REDIS_URL=redis://test-redis:6379
      - NODE_ENV=test
    networks:
      - ci-net

  # ── Test-Runner ──────────────────────────────────────
  test-runner:
    build:
      context: .
      target: development
    command: ["npm", "run", "test:integration", "--", "--forceExit"]
    depends_on:
      app-under-test:
        condition: service_started
      test-db:
        condition: service_healthy
    environment:
      - DATABASE_URL=postgresql://testuser:testpass@test-db:5432/testdb
      - APP_URL=http://app-under-test:3000
      - NODE_ENV=test
    volumes:
      - ./test-results:/app/test-results    # Test-Reports für CI-Artefakte
    networks:
      - ci-net

networks:
  ci-net:
    driver: bridge
```

**Ausführung in der Pipeline:**
```bash
# Tests ausführen, Exit-Code des test-runner zurückgeben
docker compose -f docker-compose.ci.yml run --rm test-runner

# Cleanup (immer, auch bei Fehler)
docker compose -f docker-compose.ci.yml down -v --remove-orphans
```

> **Performance-Trick:** `tmpfs` für Datenbank-Volumes in CI mountet den Datenbankpfad in den RAM statt auf die Festplatte. Das kann Integration-Tests um **30–60% beschleunigen**, da Disk-I/O entfällt.[^4]

***

### A.2 GitHub Actions mit Docker Compose

GitHub Actions hat Docker Compose nativ auf allen Runnern verfügbar. Das folgende Workflow-Beispiel zeigt das vollständige CI-Pattern für ein Node.js-Projekt mit PostgreSQL:[^5][^1]

```yaml
# .github/workflows/integration-tests.yml
name: Integration Tests

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Cache Docker layers
        uses: actions/cache@v4
        with:
          path: /tmp/.buildx-cache
          key: ${{ runner.os }}-buildx-${{ github.sha }}
          restore-keys: ${{ runner.os }}-buildx-

      - name: Start test infrastructure
        run: docker compose -f docker-compose.ci.yml up -d test-db test-redis

      - name: Wait for services to be healthy
        run: |
          docker compose -f docker-compose.ci.yml ps
          # Warte explizit auf health checks
          timeout 60 bash -c \
            'until docker compose -f docker-compose.ci.yml ps | grep -q "healthy"; do sleep 2; done'

      - name: Run integration tests
        run: |
          docker compose -f docker-compose.ci.yml run --rm \
            -e CI=true \
            test-runner

      - name: Upload test results
        if: always()              # Auch bei Fehler hochladen
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: test-results/

      - name: Cleanup
        if: always()
        run: docker compose -f docker-compose.ci.yml down -v --remove-orphans
```

***

### A.3 GitLab CI mit Self-Hosted Runner via Docker Compose

Anstatt teure SaaS-Runner zu nutzen, kann ein GitLab CI Runner komplett in Docker Compose betrieben werden:[^6][^7][^8]

```yaml
# /opt/docker/gitlab-runner/docker-compose.yml
# Persistenter GitLab CI Runner für WSL2/Debian

services:
  gitlab-runner:
    image: gitlab/gitlab-runner:alpine
    container_name: gitlab-runner
    restart: unless-stopped
    volumes:
      - gitlab_runner_config:/etc/gitlab-runner
      - /var/run/docker.sock:/var/run/docker.sock  # Docker-in-Docker via Socket-Sharing
    environment:
      - TZ=Europe/Berlin

volumes:
  gitlab_runner_config:
```

**Runner registrieren** (einmalig nach dem ersten Start):
```bash
docker compose exec gitlab-runner gitlab-runner register \
  --non-interactive \
  --url "https://gitlab.com/" \
  --registration-token "DEIN_PROJECT_TOKEN" \
  --executor "docker" \
  --docker-image "docker:latest" \
  --docker-volumes "/var/run/docker.sock:/var/run/docker.sock" \
  --description "WSL2-Docker-Runner" \
  --tag-list "docker,compose,debian" \
  --run-untagged="true" \
  --locked="false"
```

**Nutzung in `.gitlab-ci.yml`:**
```yaml
# .gitlab-ci.yml – läuft auf dem selbst gehosteten Runner

stages:
  - test
  - build
  - deploy

integration-test:
  stage: test
  tags:
    - docker
  script:
    - docker compose -f docker-compose.ci.yml up -d test-db
    - docker compose -f docker-compose.ci.yml run --rm test-runner
  after_script:
    - docker compose -f docker-compose.ci.yml down -v
  artifacts:
    reports:
      junit: test-results/junit.xml
    when: always
```

> **Sicherheitshinweis:** Das Teilen des Docker-Sockets (`/var/run/docker.sock`) gibt dem Runner volle Docker-Kontrolle. Für isoliertere Builds gibt es die Alternative **Docker-in-Docker (dind)** mit `privileged: true`, was aber eigene Sicherheitsimplikationen hat.[^9]

***

### A.4 Vollständige Self-Hosted CI-Infrastruktur mit Gitea + Drone

Für ein vollständig self-hosted Setup kombiniert man Gitea (Git-Server) mit Drone CI – alles in einer Compose-Datei:[^10]

```yaml
# /opt/docker/ci/docker-compose.yml
services:
  # ── Gitea – Self-Hosted Git ──────────────────────────
  gitea:
    image: gitea/gitea:latest
    container_name: gitea
    restart: unless-stopped
    environment:
      - USER_UID=1000
      - USER_GID=1000
      - GITEA__database__DB_TYPE=postgres
      - GITEA__database__HOST=gitea-db:5432
      - GITEA__database__NAME=gitea
      - GITEA__database__USER=gitea
      - GITEA__database__PASSWD_FILE=/run/secrets/gitea_db_pass
    ports:
      - "3000:3000"
      - "2222:22"
    volumes:
      - gitea_data:/data
    secrets:
      - gitea_db_pass
    depends_on:
      gitea-db:
        condition: service_healthy
    networks:
      - ci-infra

  gitea-db:
    image: postgres:16-alpine
    container_name: gitea-db
    restart: unless-stopped
    environment:
      POSTGRES_DB: gitea
      POSTGRES_USER: gitea
      POSTGRES_PASSWORD_FILE: /run/secrets/gitea_db_pass
    volumes:
      - gitea_db_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U gitea"]
      interval: 10s
      retries: 5
    secrets:
      - gitea_db_pass
    networks:
      - ci-infra

  # ── Drone CI Server ──────────────────────────────────
  drone:
    image: drone/drone:2
    container_name: drone
    restart: unless-stopped
    environment:
      - DRONE_GITEA_SERVER=http://gitea:3000
      - DRONE_GITEA_CLIENT_ID=${DRONE_GITEA_CLIENT_ID}
      - DRONE_GITEA_CLIENT_SECRET_FILE=/run/secrets/drone_gitea_secret
      - DRONE_RPC_SECRET_FILE=/run/secrets/drone_rpc_secret
      - DRONE_SERVER_HOST=drone.intern
      - DRONE_SERVER_PROTO=http
    ports:
      - "8080:80"
    volumes:
      - drone_data:/data
    secrets:
      - drone_gitea_secret
      - drone_rpc_secret
    depends_on:
      - gitea
    networks:
      - ci-infra

  # ── Drone Runner (führt Jobs aus) ────────────────────
  drone-runner:
    image: drone/drone-runner-docker:1
    container_name: drone-runner
    restart: unless-stopped
    environment:
      - DRONE_RPC_PROTO=http
      - DRONE_RPC_HOST=drone:80
      - DRONE_RPC_SECRET_FILE=/run/secrets/drone_rpc_secret
      - DRONE_RUNNER_CAPACITY=2      # Max. 2 parallele Jobs
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    secrets:
      - drone_rpc_secret
    depends_on:
      - drone
    networks:
      - ci-infra

networks:
  ci-infra:
    driver: bridge

volumes:
  gitea_data:
  gitea_db_data:
  drone_data:

secrets:
  gitea_db_pass:
    file: ./secrets/gitea_db_pass.txt
  drone_gitea_secret:
    file: ./secrets/drone_gitea_secret.txt
  drone_rpc_secret:
    file: ./secrets/drone_rpc_secret.txt
```

***

## Teil B – Scheduled Jobs und One-Off-Tasks

### B.1 Das Problem: Docker Compose und Scheduling

Docker Compose ist für **dauerhaft laufende Services** konzipiert. Cron-Jobs passen nicht nativ ins Compose-Modell, weil ein Container entweder läuft oder nicht. Es gibt drei etablierte Lösungsansätze:[^11][^12][^13]

| Ansatz | Complexity | Flexibilität | Empfehlung |
|--------|:----------:|:------------:|------------|
| Cron im App-Container einbauen | 🟡 Mittel | 🔴 Gering | Legacy-Setups |
| Dedizierter Cron-Container mit eigenem Image | 🟡 Mittel | 🟡 Mittel | Einfache Tasks |
| **Ofelia** – Docker-nativer Scheduler | 🟢 Gering | 🟢 Hoch | **Empfohlen** |
| `docker compose run --rm` via Systemd-Timer | 🟢 Gering | 🟡 Mittel | WSL2 + Systemd |

***

### B.2 Ofelia – Der Docker-native Job-Scheduler

**Ofelia** ist der De-facto-Standard für Scheduling in Docker-Compose-Umgebungen. Er ist in Go geschrieben, hat einen minimalen Footprint (~20 MB RAM) und konfiguriert sich über **Docker Labels** – völlig ohne externe Konfigurationsdateien.[^14][^15][^16]

#### Job-Typen

| Typ | Beschreibung |
|-----|-------------|
| `job-exec` | Befehl in einem **laufenden** Container ausführen (wie `docker exec`) |
| `job-run` | Neuen Container starten, Task ausführen, Container destroyen |
| `job-local` | Befehl direkt auf dem Ofelia-Host ausführen |
| `job-service-run` | Für Docker-Swarm-Umgebungen (Service-basiert) |

#### Vollständiges Ofelia-Beispiel mit Label-Konfiguration

```yaml
# docker-compose.yml mit Ofelia Job-Scheduler

services:
  # ── Ofelia Scheduler ─────────────────────────────────
  ofelia:
    image: mcuadros/ofelia:latest
    container_name: ofelia
    restart: unless-stopped
    command: daemon --docker
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    depends_on:
      - webapp
      - db
    networks:
      - app-net

  # ── Haupt-Applikation ────────────────────────────────
  webapp:
    image: myapp:latest
    container_name: webapp
    restart: unless-stopped
    networks:
      - app-net
    labels:
      # Alle 5 Minuten: E-Mail-Queue verarbeiten
      ofelia.enabled: "true"
      ofelia.job-exec.send-emails.schedule: "@every 5m"
      ofelia.job-exec.send-emails.command: "php artisan queue:work --once"
      # Täglich um 1:00 Uhr: Cache leeren
      ofelia.job-exec.clear-cache.schedule: "0 1 * * *"
      ofelia.job-exec.clear-cache.command: "php artisan cache:clear"
      # Jeden Sonntag um 3:00 Uhr: Sitemap neu generieren
      ofelia.job-exec.sitemap.schedule: "0 3 * * 0"
      ofelia.job-exec.sitemap.command: "php artisan sitemap:generate"

  # ── Datenbank ────────────────────────────────────────
  db:
    image: mariadb:10.11
    container_name: db
    restart: unless-stopped
    environment:
      MYSQL_DATABASE: myapp
      MYSQL_ROOT_PASSWORD_FILE: /run/secrets/db_root
    volumes:
      - db_data:/var/lib/mysql
    secrets:
      - db_root
    networks:
      - app-net
    labels:
      # Täglich um 2:00 Uhr: Datenbankbackup
      ofelia.enabled: "true"
      ofelia.job-exec.db-backup.schedule: "0 2 * * *"
      ofelia.job-exec.db-backup.command: >
        sh -c 'mysqldump -u root --password=$(cat /run/secrets/db_root)
        myapp | gzip > /backups/db-$(date +%Y%m%d).sql.gz'

  # ── Backup-Sidecar mit eigenem Scheduler-Job ─────────
  # Dieser Container läuft als "dummy" dauerhaft,
  # damit Ofelia job-exec darin ausführen kann
  backup-worker:
    image: alpine:latest
    container_name: backup-worker
    restart: unless-stopped
    command: ["tail", "-f", "/dev/null"]   # Container am Laufen halten
    volumes:
      - db_data:/data:ro                  # Read-only Zugriff auf DB-Daten
      - ./backups:/backups
    networks:
      - app-net
    labels:
      ofelia.enabled: "true"
      # Stündlich: Temporäre Dateien aufräumen
      ofelia.job-exec.cleanup-tmp.schedule: "@hourly"
      ofelia.job-exec.cleanup-tmp.command: "find /backups -name '*.tmp' -delete"
      # Wöchentlich: Alte Backups entfernen (älter als 30 Tage)
      ofelia.job-exec.prune-backups.schedule: "0 4 * * 1"
      ofelia.job-exec.prune-backups.command: "find /backups -mtime +30 -delete"

networks:
  app-net:
    driver: bridge

volumes:
  db_data:

secrets:
  db_root:
    file: ./secrets/db_root.txt
```

#### Ofelia Schedule-Format

```yaml
# Standard 5-Felder Cron (Minute Stunde Tag Monat Wochentag):
"30 2 * * *"        # Täglich um 02:30 Uhr
"0 */6 * * *"       # Alle 6 Stunden
"0 9 * * 1-5"       # Wochentags um 09:00 Uhr
"15 3 1 * *"        # Am 1. jeden Monats um 03:15 Uhr
"0 3 * * 0"         # Jeden Sonntag um 03:00 Uhr

# Ofelia-Kurzformen:
"@hourly"           # Jede Stunde (= "0 * * * *")
"@daily"            # Täglich Mitternacht (= "0 0 * * *")
"@weekly"           # Jeden Sonntag Mitternacht
"@monthly"          # Ersten des Monats Mitternacht

# Intervalle:
"@every 30s"        # Alle 30 Sekunden
"@every 5m"         # Alle 5 Minuten
"@every 1h30m"      # Alle 90 Minuten
```

***

### B.3 One-Off-Tasks mit `docker compose run`

Für **einmalige Tasks** – Datenbankmigrationen, Seed-Skripte, Setup-Schritte – ist `docker compose run --rm` das richtige Werkzeug. Der Container startet, führt den Befehl aus und wird danach automatisch entfernt:[^13]

```yaml
services:
  # ── App-Container ────────────────────────────────────
  app:
    image: myapp:latest
    depends_on:
      db:
        condition: service_healthy
    environment:
      - DATABASE_URL=postgresql://user:pass@db:5432/mydb
    networks:
      - app-net

  # ── Migrations-Job (kein dauerhafter Service!) ───────
  migrate:
    image: myapp:latest
    command: ["npm", "run", "db:migrate"]
    depends_on:
      db:
        condition: service_healthy
    environment:
      - DATABASE_URL=postgresql://user:pass@db:5432/mydb
    networks:
      - app-net
    # KEIN restart: – dieser Service soll nach Job-Ende enden
    profiles: ["tools"]            # Nicht bei normalem `up` starten

  db:
    image: postgres:16-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready"]
      interval: 5s
      retries: 10
    volumes:
      - db_data:/var/lib/postgresql/data
    networks:
      - app-net

networks:
  app-net:

volumes:
  db_data:
```

**Workflow:**
```bash
# 1. Datenbank starten
docker compose up -d db

# 2. Migration ausführen (einmalig, Container wird danach gelöscht)
docker compose run --rm migrate

# 3. App starten
docker compose up -d app

# Alternativ: Migrationstask direkt ohne Profil aufrufen
docker compose run --rm app npm run db:migrate
```

***

### B.4 Systemd-Timer als externe Steuerung (WSL2-spezifisch)

Wenn Systemd in WSL2 aktiviert ist (`/etc/wsl.conf` → `systemd=true`), lassen sich `docker compose run`-Befehle als **Systemd-Timer** planen – ohne zusätzlichen Scheduler-Container:[^12]

```ini
# /etc/systemd/system/docker-backup.service
[Unit]
Description=Docker Stack Backup
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
WorkingDirectory=/opt/docker/myapp
ExecStart=/usr/bin/docker compose run --rm backup-worker
User=root
```

```ini
# /etc/systemd/system/docker-backup.timer
[Unit]
Description=Täglicher Docker-Backup um 2 Uhr

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true          # Verpassten Timer nachholen beim Systemstart

[Install]
WantedBy=timers.target
```

```bash
systemctl enable --now docker-backup.timer
systemctl list-timers --all | grep docker
```

***

### B.5 Datenbankbackup-Stack als vollständiges Beispiel

```yaml
# /opt/docker/backup/docker-compose.yml
# Vollständiger Backup-Stack für MariaDB, PostgreSQL und Volumes

services:
  # ── Volume-Backup via docker-volume-backup ───────────
  volume-backup:
    image: offen/docker-volume-backup:v2
    container_name: volume-backup
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /opt/docker/backups:/archive          # Backup-Zielverzeichnis
      # Volumes zum Backup (read-only)
      - mariadb_data:/backup/mariadb:ro
      - postgres_data:/backup/postgres:ro
    environment:
      - BACKUP_CRON_EXPRESSION=0 2 * * *      # Täglich 02:00 Uhr
      - BACKUP_FILENAME=backup-%Y-%m-%dT%H-%M-%S.tar.gz
      - BACKUP_RETENTION_DAYS=14              # 2 Wochen aufbewahren
      - BACKUP_PRUNING_LEEWAY=10m
      # Optional: Benachrichtigung bei Fehler
      - NOTIFICATION_URLS=${GOTIFY_URL}       # z.B. Gotify-Push
    labels:
      # Ofelia-Job zum Prüfen ob Backups aktuell sind
      ofelia.enabled: "true"
      ofelia.job-exec.backup-check.schedule: "@daily"
      ofelia.job-exec.backup-check.command: >
        sh -c 'LATEST=$(ls -t /archive/*.tar.gz | head -1);
        AGE=$(( ($(date +%s) - $(stat -c %Y "$LATEST")) / 3600 ));
        [ $AGE -lt 26 ] && echo "OK: Backup $AGE Stunden alt" ||
        echo "WARNUNG: Letztes Backup $AGE Stunden alt!" >&2'

  # ── MySQL-Dump-Job (Alternative für MariaDB) ─────────
  mariadb-dump:
    image: mariadb:10.11
    container_name: mariadb-dump
    restart: "no"                   # Kein Auto-Restart
    profiles: ["manual-backup"]     # Nur manuell starten
    volumes:
      - ./dumps:/dumps
    command: >
      sh -c 'mysqldump -h ${DB_HOST:-mariadb} -u root
      -p${MYSQL_ROOT_PASSWORD} --all-databases
      | gzip > /dumps/full-$(date +%Y%m%d-%H%M).sql.gz &&
      echo "Dump abgeschlossen: /dumps/full-$(date +%Y%m%d-%H%M).sql.gz"'

volumes:
  mariadb_data:
    external: true     # Bereits vorhandenes Volume aus deinem DB-Cluster
  postgres_data:
    external: true
```

***

## Teil C – Netzwerkdienste und Infrastruktur

### C.1 Warum Docker Compose für Netzwerkdienste?

Klassische Netzwerkdienste wie DNS-Server, VPN-Gateways, Reverse-Proxies oder Monitoring-Agents müssen oft besondere Linux-Kernel-Capabilities nutzen (z.B. `NET_ADMIN` für WireGuard, Port 53 für DNS). Docker Compose bietet mit `cap_add`, `sysctls`, `network_mode` und `dns` exakt die Werkzeuge, um diese Dienste reproduzierbar zu konfigurieren.[^17][^18]

***

### C.2 DNS-Infrastruktur: AdGuard Home + Unbound

**AdGuard Home** ersetzt Pi-hole mit einer moderneren Oberfläche, HTTPS/DNS-over-TLS-Support und aktivem Development. Kombiniert mit **Unbound** als recursivem DNS-Resolver entsteht eine vollständig selbstverwaltete DNS-Kette ohne externe DNS-Provider-Abhängigkeit:[^19][^17]

```yaml
# /opt/docker/network/dns/docker-compose.yml
# Netzwerkweiter DNS-Blocker mit recursivem Resolver

services:
  # ── Unbound – Recursiver DNS-Resolver ───────────────
  unbound:
    image: mvance/unbound:latest
    container_name: unbound
    restart: unless-stopped
    volumes:
      - ./unbound.conf:/opt/unbound/etc/unbound/unbound.conf:ro
    expose:
      - "53/tcp"
      - "53/udp"
    cap_add:
      - NET_ADMIN
    networks:
      dns-net:
        ipv4_address: 172.20.0.2    # Feste IP für AdGuard-Konfiguration

  # ── AdGuard Home – DNS-Blocker + DoH/DoT ────────────
  adguard:
    image: adguard/adguardhome:latest
    container_name: adguard
    restart: unless-stopped
    ports:
      - "53:53/tcp"       # Standard DNS
      - "53:53/udp"       # Standard DNS
      - "853:853/tcp"     # DNS-over-TLS
      - "3000:3000/tcp"   # Setup-Port (nur beim ersten Start)
      - "80:80/tcp"       # Web-UI (HTTP)
      - "443:443/tcp"     # Web-UI (HTTPS)
    volumes:
      - adguard_work:/opt/adguardhome/work
      - adguard_conf:/opt/adguardhome/conf
    networks:
      dns-net:
        ipv4_address: 172.20.0.3
    # Upstream-DNS auf lokalen Unbound zeigen
    # (wird in AdGuard-UI konfiguriert: 172.20.0.2:53)

  # ── Ofelia für DNS-Blocklisten-Update ─────────────────
  ofelia:
    image: mcuadros/ofelia:latest
    container_name: ofelia-dns
    restart: unless-stopped
    command: daemon --docker
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - dns-net
    labels:
      # Wöchentlich Blocklisten in AdGuard aktualisieren
      ofelia.enabled: "true"
      ofelia.job-run.update-blocklists.schedule: "@weekly"
      ofelia.job-run.update-blocklists.image: "curlimages/curl:latest"
      ofelia.job-run.update-blocklists.command: >
        curl -s -X POST http://adguard:80/control/filtering/refresh
        -H "Authorization: Basic ${ADGUARD_AUTH_B64}"

networks:
  dns-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/24

volumes:
  adguard_work:
  adguard_conf:
```

> **WSL2-Hinweis:** WSL2 nutzt standardmäßig Port 53 über `systemd-resolved`. Vor dem Start muss entweder `systemd-resolved` auf einen anderen Port umgestellt werden, oder AdGuard wird mit `network_mode: host` gestartet und bindet sich direkt an das Interface.

```bash
# systemd-resolved von Port 53 entfernen (WSL2 mit Systemd):
echo -e "[Resolve]\nDNSStubListener=no" | sudo tee /etc/systemd/resolved.conf.d/no-stub.conf
sudo systemctl restart systemd-resolved
```

***

### C.3 Reverse-Proxy: Traefik v3 als Service-Mesh

**Traefik** ist gegenüber Nginx Proxy Manager die technisch überlegene Wahl für komplexe Docker-Setups: Er erkennt automatisch neue Container über den Docker-Socket und konfiguriert Routing + TLS-Zertifikate (Let's Encrypt) ohne Neustart:[^20][^21]

```yaml
# /opt/docker/network/proxy/docker-compose.yml
# Traefik v3 als automatischer Reverse-Proxy

services:
  traefik:
    image: traefik:v3.2
    container_name: traefik
    restart: unless-stopped
    command:
      # API & Dashboard
      - "--api.dashboard=true"
      - "--api.insecure=false"

      # Docker-Provider
      - "--providers.docker=true"
      - "--providers.docker.exposedByDefault=false"  # Nur explizit aktivierte Services
      - "--providers.docker.network=proxy"

      # Entrypoints
      - "--entryPoints.web.address=:80"
      - "--entryPoints.web.http.redirections.entryPoint.to=websecure"
      - "--entryPoints.websecure.address=:443"

      # Let's Encrypt via DNS-Challenge (kein offener Port 80 nötig)
      - "--certificatesResolvers.letsencrypt.acme.dnsChallenge=true"
      - "--certificatesResolvers.letsencrypt.acme.dnsChallenge.provider=cloudflare"
      - "--certificatesResolvers.letsencrypt.acme.email=${ACME_EMAIL}"
      - "--certificatesResolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"

      # Logging
      - "--log.level=INFO"
      - "--accesslog=true"

    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - traefik_certs:/letsencrypt
    environment:
      - CF_DNS_API_TOKEN_FILE=/run/secrets/cf_api_token  # Cloudflare für DNS-Challenge
    secrets:
      - cf_api_token
    networks:
      - proxy
    labels:
      # Traefik Dashboard absichern
      - "traefik.enable=true"
      - "traefik.http.routers.dashboard.rule=Host(`traefik.${DOMAIN}`)"
      - "traefik.http.routers.dashboard.entrypoints=websecure"
      - "traefik.http.routers.dashboard.service=api@internal"
      - "traefik.http.routers.dashboard.tls.certresolver=letsencrypt"
      - "traefik.http.routers.dashboard.middlewares=auth"
      - "traefik.http.middlewares.auth.basicauth.usersfile=/letsencrypt/.htpasswd"

networks:
  proxy:
    name: proxy                 # Fester Netzwerk-Name für andere Stacks
    driver: bridge

volumes:
  traefik_certs:

secrets:
  cf_api_token:
    file: ./secrets/cf_api_token.txt
```

**Jede andere App bekommt Traefik-Routing über Labels** – ohne Traefik neu zu starten:

```yaml
# In einem anderen docker-compose.yml (z.B. Gitea):
services:
  gitea:
    image: gitea/gitea:latest
    networks:
      - proxy                           # Muss im Traefik-Netzwerk sein
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.gitea.rule=Host(`git.${DOMAIN}`)"
      - "traefik.http.routers.gitea.entrypoints=websecure"
      - "traefik.http.routers.gitea.tls.certresolver=letsencrypt"
      - "traefik.http.services.gitea.loadbalancer.server.port=3000"

networks:
  proxy:
    external: true                      # Das bereits existierende Traefik-Netzwerk
```

***

### C.4 VPN-Gateway: WireGuard + AdGuard Home

Ein selbst gehostetes VPN ermöglicht sicheren Remote-Zugriff auf alle Docker-Services. **WG-Easy** kombiniert WireGuard mit einer komfortablen Web-UI:[^18][^19]

```yaml
# /opt/docker/network/vpn/docker-compose.yml
# WireGuard VPN + AdGuard Home DNS-Blocker

services:
  # ── WG-Easy (WireGuard + Web-UI) ─────────────────────
  wg-easy:
    image: ghcr.io/wg-easy/wg-easy:latest
    container_name: wg-easy
    restart: unless-stopped
    cap_add:
      - NET_ADMIN           # Netzwerk-Interfaces verwalten
      - SYS_MODULE          # Kernel-Module laden
    sysctls:
      - net.ipv4.ip_forward=1           # IP-Forwarding aktivieren
      - net.ipv4.conf.all.src_valid_mark=1
    ports:
      - "51820:51820/udp"   # WireGuard UDP
      - "51821:51821/tcp"   # Web-UI
    volumes:
      - wg_data:/etc/wireguard
    environment:
      - WG_HOST=${PUBLIC_IP_OR_DOMAIN}  # Öffentliche IP oder DynDNS-Domain
      - WG_DEFAULT_DNS=10.8.0.2         # AdGuard als DNS für VPN-Clients
      - WG_ALLOWED_IPS=0.0.0.0/0        # Ganzer Traffic durch VPN (Full-Tunnel)
      - PASSWORD_HASH=${WG_PASSWORD_HASH}
      - TZ=Europe/Berlin
    networks:
      vpn-net:
        ipv4_address: 10.8.0.1

  # ── AdGuard Home für VPN-Clients ─────────────────────
  adguard-vpn:
    image: adguard/adguardhome:latest
    container_name: adguard-vpn
    restart: unless-stopped
    volumes:
      - adguard_vpn_work:/opt/adguardhome/work
      - adguard_vpn_conf:/opt/adguardhome/conf
    networks:
      vpn-net:
        ipv4_address: 10.8.0.2   # Diese IP wird WireGuard-Clients als DNS gegeben

networks:
  vpn-net:
    driver: bridge
    ipam:
      config:
        - subnet: 10.8.0.0/24

volumes:
  wg_data:
  adguard_vpn_work:
  adguard_vpn_conf:
```

***

### C.5 Kompletter Netzwerk-Stack: Traefik + AdGuard + WireGuard + Watchtower

Das folgende Beispiel zeigt einen **produktionsreifen, vollintegrierten Netzwerk-Stack** für ein WSL2/Homelab-Setup:[^21][^20]

```yaml
# /opt/docker/network/docker-compose.yml
# Vollständiger Netzwerk-Infrastruktur-Stack

services:
  # ── Traefik Reverse-Proxy ────────────────────────────
  traefik:
    image: traefik:v3.2
    container_name: traefik
    restart: unless-stopped
    command:
      - "--providers.docker.exposedByDefault=false"
      - "--entryPoints.web.address=:80"
      - "--entryPoints.websecure.address=:443"
      - "--api.dashboard=true"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - traefik_certs:/letsencrypt
    networks:
      - proxy
      - internal

  # ── AdGuard Home – Netzwerkweiter DNS-Blocker ────────
  adguard:
    image: adguard/adguardhome:latest
    container_name: adguard
    restart: unless-stopped
    ports:
      - "53:53/tcp"
      - "53:53/udp"
    volumes:
      - adguard_work:/opt/adguardhome/work
      - adguard_conf:/opt/adguardhome/conf
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.adguard.rule=Host(`dns.${DOMAIN:-local}`)"
      - "traefik.http.routers.adguard.entrypoints=websecure"
      - "traefik.http.services.adguard.loadbalancer.server.port=3000"
    networks:
      - proxy
      - internal

  # ── WireGuard VPN ────────────────────────────────────
  wireguard:
    image: ghcr.io/wg-easy/wg-easy:latest
    container_name: wireguard
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.ip_forward=1
    ports:
      - "51820:51820/udp"
    volumes:
      - wg_data:/etc/wireguard
    environment:
      - WG_HOST=${WG_HOST}
      - WG_DEFAULT_DNS=${ADGUARD_IP:-172.20.0.10}
      - TZ=Europe/Berlin
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.vpn-ui.rule=Host(`vpn.${DOMAIN:-local}`)"
      - "traefik.http.routers.vpn-ui.entrypoints=websecure"
      - "traefik.http.services.vpn-ui.loadbalancer.server.port=51821"
    networks:
      - proxy
      - internal

  # ── Watchtower – Auto-Updates ────────────────────────
  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WATCHTOWER_SCHEDULE=0 0 4 * * 1   # Montags 04:00 Uhr
      - WATCHTOWER_CLEANUP=true
      - TZ=Europe/Berlin
    networks:
      - internal

networks:
  proxy:
    name: proxy
    driver: bridge
  internal:
    driver: bridge

volumes:
  traefik_certs:
  adguard_work:
  adguard_conf:
  wg_data:
```

***

## Übersicht: Einsatzgebiete auf einen Blick

| Kategorie | Konkrete Tools / Setups | `compose`-Schlüssel-Features |
|-----------|------------------------|------------------------------|
| **Integration Testing** | PostgreSQL, Redis, Elasticsearch als Test-Infra | `tmpfs`, `healthcheck`, `depends_on condition`, `profiles` |
| **CI-Runner** | GitLab Runner, Drone CI, GitHub Self-Hosted | `volumes: docker.sock`, `restart: unless-stopped` |
| **Scheduled Jobs** | Ofelia, docker-cron, Systemd-Timer | Docker-Labels, `profiles: tools`, `command: tail -f /dev/null` |
| **Datenbankbackup** | docker-volume-backup, mysqldump-Container | `volumes external`, `restart: "no"`, `profiles: manual-backup` |
| **DNS-Server** | AdGuard Home + Unbound, Pi-hole | `cap_add: NET_ADMIN`, `ports: 53/tcp+udp`, feste IPs via `ipam` |
| **Reverse-Proxy** | Traefik v3, Nginx Proxy Manager | Docker-Labels für Routing, externe Netzwerke (`external: true`) |
| **VPN-Gateway** | WireGuard (wg-easy), OpenVPN | `sysctls: net.ipv4.ip_forward`, `cap_add: SYS_MODULE`, `network_mode` |
| **Monitoring** | Prometheus + Grafana + Node Exporter | `expose` statt `ports`, gemeinsames Monitoring-Netzwerk |
| **Auto-Update** | Watchtower | Docker-Socket, `WATCHTOWER_SCHEDULE` |

***

## Best Practices für komplexe Stacks

### Secrets für Netzwerkdienste

Passwörter, API-Tokens (Cloudflare, DuckDNS) und WireGuard-Preshared-Keys niemals als Umgebungsvariablen hartkodieren. Das `_FILE`-Suffix vieler Docker-Images ermöglicht das Lesen aus Secret-Dateien:[^22]

```yaml
environment:
  - CF_DNS_API_TOKEN_FILE=/run/secrets/cf_token   # Cloudflare Token aus Secret
  - WG_PASSWORD_HASH_FILE=/run/secrets/wg_pass    # WireGuard UI Passwort-Hash

secrets:
  cf_token:
    file: ./secrets/cloudflare_token.txt
  wg_pass:
    file: ./secrets/wg_password_hash.txt
```

### Netzwerk-Isolation für Sicherheit

DNS-Server und VPN-Services sollten nie im selben Netzwerk wie Anwendungsdatenbanken liegen. Die Segmentierung schützt vor Lateral-Movement im Fall einer Kompromittierung:[^23]

```yaml
networks:
  proxy:        # Traefik + öffentliche Services
  internal:     # VPN, DNS – kein direkter Internet-Zugang
  databases:    # Nur von App-Containern erreichbar
  monitoring:   # Prometheus, Grafana – read-only Zugriff
```

### Kernel-Capabilities für Netzwerkdienste

| Service | Benötigte Capabilities | Zweck |
|---------|----------------------|-------|
| WireGuard | `NET_ADMIN`, `SYS_MODULE` | VPN-Interface und Kernel-Modul laden |
| Pi-hole / AdGuard | `NET_ADMIN` (optional) | DHCP-Server-Funktionalität |
| Traefik | keine extra | Läuft als normaler Prozess |
| Open vSwitch | `NET_ADMIN`, `NET_RAW` | Netzwerk-Switching |
| iptables-basierte Firewall | `NET_ADMIN`, `NET_RAW` | Paketfilterung |

```yaml
services:
  wireguard:
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.src_valid_mark=1
      - net.ipv6.conf.all.forwarding=1   # Für IPv6-Support
```

---

## References

1. [Actions · bmuschko/docker-compose-integration-testing](https://github.com/bmuschko/docker-compose-integration-testing/actions) - bmuschko / **
docker-compose-integration-testing ** Public

Automate your workflow from idea to prod...

2. [Implementation of Continuous Integration and Continuous Deployment for Automated System Deployment](https://jurnal.kdi.or.id/index.php/bt/article/view/3295) - The increasing demand for software systems that are continuously updated requires deployment process...

3. [Using Docker Containers for Integration Testing in GitLab](https://spin.atomicobject.com/integration-testing-gitlab/) - Testing the integration of components hosted in different repositories adds another wrinkle, but Doc...

4. [Docker Compose Testing Strategy with Gitlab CI - DEV Community](https://dev.to/zavoloklom/docker-compose-testing-strategy-with-gitlab-ci-3jid) - This article provides a detailed guide on validating and testing Docker Compose setups using GitLab ...

5. [Docker Compose with Tests Action - GitHub Marketplace](https://github.com/marketplace/actions/docker-compose-with-tests-action) - # Docker Compose with Tests Action
Actions

Run your docker-compose file and excute tests inside one...

6. [GitHub - kmbn/gitlab-runner-docker-compose: A GitLab Runner instance that can run Docker and docker-compose in a GitLab CI/CD pipeline](https://github.com/kmbn/gitlab-runner-docker-compose) - kmbn / **
gitlab-runner-docker-compose ** Public

# kmbn/gitlab-runner-docker-compose

kmbn

b4c4e7a...

7. [GitHub - ajohnsc/gitlab-runner-docker-compose: Running GitLab's Runner in a Docker environment, using Docker Compose](https://github.com/ajohnsc/gitlab-runner-docker-compose) - ajohnsc / **
gitlab-runner-docker-compose ** Public

# ajohnsc/gitlab-runner-docker-compose

ajohnsc...

8. [🚀 GitLab Docker Compose | Register GitLab Runner using Docker Compose 🐳](https://www.youtube.com/watch?v=jTJEtvQH4Qc) - ## DevOps in Action
##### Nov 02, 2025 (0:28:56)
*🚀 Day 2: # GitLab Docker Compose ⚙ (Register GitLa...

9. [Run integration tests using Docker inside a dockerized GitLab runner](https://betweendata.io/posts/integration-tests-using-gitlab/) - In this post I'll show how I run integration tests using Docker inside a dockerized GitLab runner. I...

10. [GitHub - kidVTP/selfhosted-pihole: docker compose + traefik + tailscale](https://github.com/kidVTP/selfhosted-pihole) - kidVTP / **
selfhosted-pihole ** Public
forked from subdavis/selfhosted

# kidVTP/selfhosted-pihole
...

11. [What is the best approach for adding cron jobs (scheduled tasks) for a particular service in docker-compose](https://stackoverflow.com/questions/53536318/what-is-the-best-approach-for-adding-cron-jobs-scheduled-tasks-for-a-particula) - I'm using a docker-compose. I have a web and a worker service. version: '3' services: web: build: . ...

12. [Docker Cron Jobs: Complete Container Scheduling Guide](https://crontab.io/resources/docker-cron-jobs) - Master container scheduling with Docker cron jobs, Docker Compose automation, Kubernetes CronJobs, a...

13. [Adding Cron Jobs to a Docker Compose application - Distr](https://distr.sh/blog/docker-compose-cron-jobs/) - Learn three production-ready approaches to implement cron jobs in Docker Compose: lightweight schedu...

14. [ofelia/README.md at master · mcuadros/ofelia](https://github.com/mcuadros/ofelia/blob/master/README.md) - mcuadros / **
ofelia ** Public

##

# README.md

## Latest commit

 

## History
History

249 lines ...

15. [Set Up Ofelia — A Docker-Native Cron Job Scheduler with Web UI ...](https://www.tencentcloud.com/techpedia/143932) - Standard cron works fine, but if you're running a Docker-based setup, Ofelia is ...

16. [Day 40: Ofelia – Your Docker Cron Job Buddy – 7 Days of Docker](https://portalzine.de/day-40-ofelia-your-docker-cron-job-buddy-7-days-of-docker/) - So you're running Docker containers and need to schedule some tasks? Let me introduce you to Ofelia ...

17. [GitHub - Chr1stian/ad-wire-guard: Setup instructions for Adguard Home and WireGuard](https://github.com/Chr1stian/ad-wire-guard) - Chr1stian / **
ad-wire-guard ** Public

# Chr1stian/ad-wire-guard

Chr1stian

4944284 · May 23, 2021...

18. [Set Up a Secure WireGuard VPN with Docker & Docker Compose | Step-by-Step Tutorial](https://www.youtube.com/watch?v=nwzlej_lwl8) - In this tutorial, you’ll learn how to quickly and securely deploy a WireGuard VPN server using Docke...

19. [WG Easy with AdGuard Home in Docker - Complete Self-Hosted VPN Setup](https://www.youtube.com/watch?v=K2hzkBX8ma8) - .......
Build a secure VPN with network-wide ad blocking using WG Easy and AdGuard Home. A modern, a...

20. [AdGuard Home running behind a WireGuard VPN using ...](https://github.com/AdguardTeam/AdGuardHome/discussions/6857) - AdguardTeam / **
AdGuardHome ** Public

# AdGuard Home running behind a WireGuard VPN using Gluetun ...

21. [Ultimate Home Network Setup: Docker, Traefik & WireGuard](https://kitemetric.com/blogs/efficient-home-network-setup-with-docker-traefik-and-wireguard) - Secure and efficient home network setup using Docker, Traefik, and WireGuard. This guide tackles com...

22. [Manage secrets securely in Docker Compose](https://docs.docker.com/compose/how-tos/use-secrets/) - Getting a secret into a container is a two-step process. First, define the secret using the top-leve...

23. [How to Deploy Apps with Docker Compose in 2025 - Dokploy](https://dokploy.com/blog/how-to-deploy-apps-with-docker-compose-in-2025) - Docker Compose in 2025 introduces advanced features that simplify multi-container app deployment. Ke...

