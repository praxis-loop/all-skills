---
name: server-docker-compose-standard
description: Standardize Linux server service deployments under /opt/docker with one Docker Compose project per service. Use this skill whenever the user asks to audit, migrate, normalize, consolidate, or deploy server services with Docker, docker compose, docker-compose.yaml, /opt/docker, VPS, Ubuntu servers, exposed ports, restart policies, or asks how to make future agents follow the same deployment convention across servers.
---

# Server Docker Compose Standard

## Purpose

Use this skill to make server deployments boring, reproducible, and easy for the next agent to understand. The target convention is:

```text
/opt/docker/<service-name>/docker-compose.yaml
```

Every long-running business service should be managed by Docker Compose from that directory. The server-local `/opt/docker/AGENTS.md` documents the same convention for future agents after the migration.

## When To Use

Use this skill when the user wants to:

- summarize or audit services running on a Linux server;
- migrate scattered Docker, systemd, nohup, tmux, npm, Python, or manual services into Compose;
- standardize service directories under `/opt/docker`;
- create or update deployment instructions for future agents;
- push deployment changes back to a service repository;
- make another server follow the same deployment pattern.

## Safety Model

Treat production servers as live systems. Prefer read-only discovery first, then make narrowly scoped changes.

- Do not print secrets, tokens, private keys, cookies, or full `.env` contents.
- Do not delete old deployment directories during migration. Rename old Compose files with a clear suffix such as `.migrated-to-opt-docker`.
- Do not change public port exposure, proxy topology, database storage, or service behavior unless the user asks for that change.
- Before stopping or replacing a service, identify the exact process/container using the port and preserve a rollback path.
- If pushing to Git, inspect status and diffs first. Commit only relevant deployment files and never commit `.env`, `secrets/`, logs, or generated runtime data.

## Discovery Checklist

Run read-only checks before changing anything:

```bash
hostname && whoami && uname -a
sudo -n true && echo "sudo=yes" || echo "sudo=no"
systemctl list-units --type=service --state=running --no-pager --plain
systemctl --user list-units --type=service --state=running --no-pager --plain 2>/dev/null || true
sudo docker ps
sudo docker compose ls 2>/dev/null || true
sudo ss -tulpn
crontab -l 2>/dev/null || true
sudo crontab -l 2>/dev/null || true
sudo find /home /opt /srv /var/www -maxdepth 6 \( -name 'docker-compose*.yml' -o -name 'docker-compose*.yaml' -o -name 'compose*.yml' -o -name 'compose*.yaml' -o -name 'Dockerfile' \) -print 2>/dev/null
```

For running containers, use labels to find the current Compose source:

```bash
for c in $(sudo docker ps -aq); do
  sudo docker inspect -f 'name={{.Name}} project={{index .Config.Labels "com.docker.compose.project"}} service={{index .Config.Labels "com.docker.compose.service"}} dir={{index .Config.Labels "com.docker.compose.project.working_dir"}} file={{index .Config.Labels "com.docker.compose.project.config_files"}} restart={{.HostConfig.RestartPolicy.Name}}' "$c"
done
```

## Target Layout

Create one directory per business service:

```text
/opt/docker/
  AGENTS.md
  README.md
  <service-a>/
    docker-compose.yaml
  <service-b>/
    docker-compose.yaml
```

Use `docker-compose.yaml` exactly. Avoid multiple override files unless the user explicitly wants environment-specific overlays. Prefer `.env.example` for documented variables and keep real `.env` out of Git.

## Compose Standards

Each long-running service should normally have:

- `restart: unless-stopped`;
- stable service names;
- named volumes for persistent app data;
- bind mounts only for source/config/secrets that intentionally live on the host;
- health checks for databases, APIs, queues, and other dependencies when feasible;
- `depends_on: condition: service_healthy` for services that need a dependency to be ready;
- no startup-time dependency installation in production if a Dockerfile can build an immutable image.

Keep behavior-preserving migrations conservative. It is acceptable to preserve existing port mappings at first, then recommend a second phase for reverse proxying and reducing public exposure.

## Migration Workflow

1. Inventory current services, ports, Compose files, user systemd services, cron jobs, and process working directories.
2. Classify each item:
   - business service to migrate;
   - infrastructure service to keep but standardize, such as a proxy container;
   - cloud/vendor agent to leave alone;
   - dormant config that should be documented but not started.
3. Create `/opt/docker/<service-name>` and copy the current deployment source there.
4. Rename Compose files to `docker-compose.yaml`.
5. Fold small override files into the canonical Compose file, or document why an override remains.
6. Add `restart: unless-stopped` where missing.
7. Convert naked long-running commands into Compose projects while keeping the same port and command:
   - static Python server: `python:3.13-slim`;
   - Node app: `node:24-alpine`;
   - existing service images: preserve image and command.
8. Validate before launch:

```bash
cd /opt/docker/<service-name>
sudo docker compose -f docker-compose.yaml config
```

9. Start from the new location:

```bash
sudo docker compose -f docker-compose.yaml up -d --remove-orphans
```

10. Rename old Compose files outside `/opt/docker` with `.migrated-to-opt-docker`.
11. Write or update `/opt/docker/README.md` and `/opt/docker/AGENTS.md`.
12. Verify with `docker compose ls`, `docker ps`, `ss -tulpn`, and app health checks.

## Server AGENTS.md Template

Create `/opt/docker/AGENTS.md` on each standardized server:

```markdown
# Server Docker Deployment Standard

Business services on this server are managed under `/opt/docker`.

## Required Layout

Each service lives in its own directory:

```text
/opt/docker/<service-name>/docker-compose.yaml
```

Use `docker-compose.yaml` exactly.

## Rules

- Manage long-running business services with Docker Compose from `/opt/docker/<service-name>`.
- Do not run permanent services with naked `npm start`, `python -m http.server`, `nohup`, `screen`, `tmux`, or agent child processes.
- Set `restart: unless-stopped` on every long-running service.
- Keep app state in named Docker volumes unless a bind mount is intentionally needed.
- Keep secrets out of Git. Use `.env`, Compose secrets, or mounted files with restrictive permissions.
- Before changing a running service, inspect existing containers and volumes.
- After changes, verify Compose status, container status, listening ports, and app health checks.
```

## Git Sync Workflow

If a service directory is a Git repository or maps to one:

1. Check the remote and branch:

```bash
git remote -v
git branch --show-current
git status --short
```

2. Inspect deployment diffs before staging.
3. Commit only relevant files such as `docker-compose.yaml`, `Dockerfile`, `.dockerignore`, `.env.example`, `README.md`, or source needed to reproduce the running version.
4. Exclude `.env`, `secrets/`, logs, database files, caches, and generated runtime data.
5. Run available tests or at least `docker compose config`.
6. Push only when the configured credentials have permission. If a deploy key is repo-specific, report exactly which repository can and cannot be pushed.

## Final Report

End with:

- migrated services and their `/opt/docker` paths;
- services intentionally left alone;
- public ports that remain exposed;
- verification commands and results;
- Git commits and push status;
- follow-up risks, especially databases or Redis exposed on `0.0.0.0`.
