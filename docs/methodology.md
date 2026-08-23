# Methodology — Awesome Compose Analysis & Technology Classification (Stage 1)

This document is the output of **Phase 1 / Stage 1** of the work plan: an inventory of
the `vendor/awesome-compose` examples, their technologies, Dockerfile characteristics,
and a grouping strategy used to plan reusable vs. image-specific functional tests for
the minimization pipeline (Slim Toolkit + Syft + Grype).

## 1. Example Inventory

| Example | Services (compose) | Custom Dockerfiles & Base Images | Language/Framework | Multi-stage? | # Interconnected Services | Exposed Port(s)/Access |
|---|---|---|---|---|---|---|
| angular | `web` (custom, target `builder`) | `angular/Dockerfile`: `node:17.0.1-bullseye-slim` (builder → dev-envs) | Node/Angular (dev server) | Yes | 1 | HTTP :4200 |
| apache-php | `web` (custom, target `builder`) | `app/Dockerfile`: `php:8.0.9-apache` (builder → dev-envs) | PHP/Apache | Yes | 1 | HTTP :80 |
| aspnet-mssql | `web` (custom), `db` (`azure-sql-edge:1.0.4`) | `app/aspnetapp/Dockerfile`: `dotnet/sdk:5.0` → `dotnet/aspnet:5.0` | .NET/ASP.NET | Yes (true) | 2 | HTTP :80 |
| django | `web` (custom, target `builder`) | `app/Dockerfile`: `python:3.7-alpine` (builder → dev-envs) | Python/Django | Yes | 1 | HTTP :8000 |
| elasticsearch-logstash-kibana | `elasticsearch`, `logstash`, `kibana` (all prebuilt) | none | Elastic Stack | N/A | 3 | ES :9200; Kibana :5601 |
| fastapi | `api` (custom, target `builder`) | `Dockerfile`: `tiangolo/uvicorn-gunicorn-fastapi:python3.9-slim` | Python/FastAPI | Yes | 1 | HTTP :8000 |
| flask | `web` (custom, target `builder`) | `app/Dockerfile`: `python:3.10-alpine` (builder → dev-envs) | Python/Flask | Yes | 1 | HTTP :8000 |
| flask-redis | `web` (custom), `redis` (`redislabs/redismod`) | `Dockerfile`: `python:3.10-alpine` (builder → dev-envs) | Python/Flask | Yes | 2 | HTTP :8000; Redis :6379 |
| gitea-postgres | `gitea`, `db` (postgres, all prebuilt) | none | Go (Gitea) | N/A | 2 | HTTP :3000 |
| minecraft | `minecraft` (prebuilt) | none | Java (prebuilt) | N/A | 1 | :25565 |
| nextcloud-postgres | `nc`, `db` (all prebuilt) | none | PHP (Nextcloud) | N/A | 2 | HTTP :80 |
| nextcloud-redis-mariadb | `nc`, `redis`, `db` (all prebuilt) | none | PHP (Nextcloud) | N/A | 3 | HTTP :80 |
| nginx-aspnet-mysql | `backend` (custom), `db` (mariadb), `proxy` (custom) | `backend`: `dotnet/sdk:6.0` → `dotnet/aspnet:6.0` (5 stages); `proxy`: `nginx:1.13-alpine` | .NET + Nginx | backend: Yes; proxy: No | 3 | HTTP :80 (proxy) |
| nginx-flask-mongo | `web` (nginx), `backend` (custom), `mongo` | `flask/Dockerfile`: `python:3.10-alpine` | Python/Flask + Nginx | backend: Yes | 3 | HTTP :80 |
| nginx-flask-mysql | `db`, `backend` (custom), `proxy` (custom) | `backend`: `python:3.10-alpine`; `proxy`: `nginx:1.13-alpine` | Python/Flask + Nginx | backend: Yes; proxy: No | 3 | HTTP :80 |
| nginx-golang | `proxy` (nginx), `backend` (custom, target `builder`) | `backend/Dockerfile`: `golang:1.18-alpine` → `scratch` (unused final) | Go | Yes (3 stages) | 2 | HTTP :80 |
| nginx-golang-mysql | `backend` (custom), `db`, `proxy` (nginx) | `golang:1.18-alpine` → `scratch` (unused final) | Go | Yes | 3 | HTTP :80 |
| nginx-golang-postgres | `backend` (custom), `db`, `proxy` (nginx) | `golang:1.18-alpine` → `scratch` (unused final) | Go | Yes | 3 | HTTP :80 |
| nginx-nodejs-redis | `redis`, `web1`, `web2` (custom), `nginx` (custom) | `web/Dockerfile`: `node:14.17.3-alpine3.14`; `nginx/Dockerfile`: `nginx:1.21.6` | Node/Express + Nginx LB | No | 4 | HTTP :80; web1 :81, web2 :82 |
| nginx-wsgi-flask | `nginx-proxy` (custom), `flask-app` (custom) | `flask/Dockerfile`: `python:3.9.2-alpine` (non-root, venv); `nginx/Dockerfile`: `nginx:1.19.7-alpine` (non-root) | Python/Flask (gunicorn) + Nginx | No | 2 | HTTP :80 |
| pihole-cloudflared-DoH | `cloudflared`, `pihole` (all prebuilt) | none | DNS/DoH | N/A | 2 | DNS :53; admin :8080/:8443 |
| plex | `plex` (prebuilt, host networking) | none | Media server | N/A | 1 | :32400 (host) |
| portainer | `portainer` (prebuilt) | none | Go (Portainer) | N/A | 1 | HTTP :9000 |
| postgresql-pgadmin | `postgres`, `pgadmin` (all prebuilt) | none | DB + admin UI | N/A | 2 | pgAdmin :5050 |
| prometheus-grafana | `prometheus`, `grafana` (all prebuilt) | none | Monitoring | N/A | 2 | Prometheus :9090; Grafana :3000 |
| react-express-mongodb | `frontend`, `backend` (custom, target `development`), `mongo` | `backend`: `node:lts-buster-slim`; `frontend`: `node:lts-buster` | Node/Express + React | Yes (dev-envs only) | 3 | HTTP :3000 |
| react-express-mysql | `backend` (custom), `db`, `frontend` (custom) | `backend`: `node:lts`; `frontend`: `node:lts` → `nginx:1.13-alpine` (unused prod stage) | Node/Express + React | frontend: Yes (unused prod) | 3 | HTTP :80 (backend), :3000 (frontend) |
| react-java-mysql | `backend` (custom), `db`, `frontend` (custom, target `development`) | `backend`: `maven:3.8.5-eclipse-temurin-17` → `eclipse-temurin:17-jre-focal`; `frontend`: `node:lts` → `nginx:1.13-alpine` (unused prod) | Java/Spring Boot + React | backend: Yes (true); frontend: Yes (unused prod) | 3 | Backend :8080; frontend :3000 |
| react-nginx | `frontend` (custom, single service) | `Dockerfile`: `node:lts` (build) → `nginx:alpine` (final, used) | React served by Nginx | Yes (true, used) | 1 | HTTP :80 |
| react-rust-postgres | `frontend`, `backend` (custom, target `development`), `db` | `backend`: `rust:buster` → `debian:buster-slim` (unused); `frontend`: `node:lts` → `nginx:1.13-alpine` (unused) | Rust (Rocket) + React | Yes (unused prod stages) | 3 | Backend :8000; frontend :3000 |
| sparkjava | `sparkjava` (custom) | `maven:3.8.5-eclipse-temurin-17` → `eclipse-temurin:17-jre-focal` | Java/SparkJava | Yes (true) | 1 | HTTP :8080 |
| sparkjava-mysql | `backend` (custom), `db` | same as above | Java/SparkJava | Yes (true) | 2 | HTTP :8080 |
| spring-postgres | `backend` (custom), `db` | `maven:3.8.5-eclipse-temurin-17` → `eclipse-temurin:17-jre-focal` | Java/Spring Boot | Yes (true) | 2 | HTTP :8080 |
| traefik-golang | `frontend` (traefik:2.6), `backend` (custom) | `golang:1.18` → `scratch` (used) | Go + Traefik | Yes (true, used) | 2 | HTTP :80 (via Traefik) |
| vuejs | `web` (custom, target `development`) | `vuejs/Dockerfile`: `node:14.4.0-alpine` | Node/Vue (dev server) | Yes (dev-envs only) | 1 | HTTP :8080 |
| wasmedge-kafka-mysql | `redpanda`, `etl` (custom, WASM), `db` | `etl/Dockerfile`: `rust:1.64` → `scratch` (wasmedge runtime) | Rust → WASM | Yes (true) | 3 | Redpanda :9092; etl no published port |
| wasmedge-mysql-nginx | `frontend` (nginx:alpine), `backend` (custom, WASM), `db` | `backend/Dockerfile`: `rust:1.64` → `scratch` (wasmedge runtime) | Rust → WASM | Yes (true) | 3 | Frontend :8090; backend :8080 |
| wireguard | `wireguard` (prebuilt) | none | VPN | N/A | 1 | UDP :51820 |

**Note:** `elasticsearch-logstash-kibana`, `gitea-postgres`, `minecraft`, `nextcloud-postgres`,
`nextcloud-redis-mariadb`, `pihole-cloudflared-DoH`, `plex`, `portainer`, `postgresql-pgadmin`,
`prometheus-grafana`, `wireguard` use **only prebuilt images** — there is no application
Dockerfile to build/minimize here. These are useful later (Phase 6) as "third-party image"
minimization candidates, but are out of scope for the initial custom-build pipeline.

**Multi-stage caveat:** several examples define a Dockerfile with a smaller production/final
stage (e.g. `scratch`, `nginx:alpine` static serve, `debian-slim`) that the example's
`docker-compose.yaml` does **not** actually build (compose pins `target: development`/`builder`
instead). Affected: `nginx-golang*`, `react-express-mysql` (frontend), `react-java-mysql`
(frontend), `react-rust-postgres`. This is itself a first, "free" minimization opportunity we
should note per-image (retarget the compose build to the final stage) before even running Slim.

## 2. Technology Clustering

| Cluster | Examples | Reusable test basis |
|---|---|---|
| Python (Flask/Django/FastAPI) | django, fastapi, flask, flask-redis, nginx-flask-mongo, nginx-flask-mysql, nginx-wsgi-flask | Generic HTTP GET/health-check test + route-specific assertions |
| Node (Express backend / React·Vue·Angular frontend) | angular, vuejs, react-nginx, react-express-mongodb, react-express-mysql, nginx-nodejs-redis, (react-rust-postgres frontend) | Generic HTTP GET on dev server / static bundle load |
| Java (Spring / SparkJava) | spring-postgres, react-java-mysql (backend), sparkjava, sparkjava-mysql | Generic HTTP GET + REST endpoint checks |
| Go | nginx-golang, nginx-golang-mysql, nginx-golang-postgres, traefik-golang | Generic HTTP GET behind reverse proxy |
| .NET/ASP.NET | aspnet-mssql, nginx-aspnet-mysql | Generic HTTP GET + DB connectivity check |
| PHP | apache-php | Generic HTTP GET |
| Rust / WASM | react-rust-postgres (backend), wasmedge-kafka-mysql, wasmedge-mysql-nginx | HTTP GET / message-queue produce-consume check |
| Reverse proxy pattern (nginx/Traefik in front of an app) | nginx-golang*, nginx-flask-*, nginx-aspnet-mysql, nginx-nodejs-redis, nginx-wsgi-flask, traefik-golang, wasmedge-mysql-nginx | Proxy passthrough test (request via proxy port reaches backend) |
| Prebuilt-image only (no custom Dockerfile — deferred to Phase 6) | elasticsearch-logstash-kibana, gitea-postgres, minecraft, nextcloud-postgres, nextcloud-redis-mariadb, pihole-cloudflared-DoH, plex, portainer, postgresql-pgadmin, prometheus-grafana, wireguard | N/A (no build step to minimize) |

## 3. Testing Strategy (generic vs. image-specific)

**Generic test layer** (`tests/generic/`), reusable across nearly all clusters:
1. `container_up.sh` — container starts and stays running (no immediate crash/restart loop).
2. `http_health.sh <url>` — HTTP request to the app's main port returns a 2xx/3xx status.
3. `port_listen.sh <port>` — TCP port is open/listening inside the container.
4. `proxy_passthrough.sh <proxy_url> <expected_marker>` — for the reverse-proxy cluster, verifies
   a request through the proxy is actually served by the backend (not just the proxy's own default page).
5. `db_connectivity.sh` — for stacks with a DB service, verifies the app-to-DB connection succeeds
   (e.g. via an app endpoint that touches the DB, since Slim's dynamic analysis needs the app to
   exercise its real code paths, not just a raw DB ping).

**Image-specific test layer** (`tests/specific/<example-name>/`):
- Concrete routes/APIs exercised per example (e.g. Flask `/` vs Django admin routes vs Spring
  Boot `/actuator/health` vs a SparkJava REST endpoint).
- Framework quirks: dev-server vs prod-server differences (Angular/Vue/React dev servers need
  different readiness checks than an nginx-served static bundle).
- Multi-service call chains (e.g. `nginx-flask-mongo`: hit nginx → assert it reached Flask →
  assert Flask read/wrote to Mongo).
- WASM-specific: verifying the wasmedge runtime path is invoked correctly (not just "port open").

**How this maps to Slim:** the generic + specific scripts for a given image are what gets passed
to `docker-slim`/`mint`'s HTTP probe / exec-based dynamic analysis (Stage 3/4), so that minimization
only removes files/packages genuinely unused by the exercised code paths.

## 4. Recommended Initial Example (Stage 2 entry point)

Recommendation: start with **`flask`** (single service, custom Dockerfile, no multi-stage
production target ambiguity, minimal surface) to validate the full pipeline end-to-end
(build → baseline test → SBOM → Grype → Slim → post-test → compare), then immediately follow
with **`flask-redis`** to validate the pipeline against an interconnected multi-service example
before generalizing to other clusters.

## 5. Production Recommendation: SBOM/Vulnerability Scanning Order

Slim's dynamic analysis strips package metadata (e.g. Python `*.dist-info`, Alpine's `apk`
database) alongside genuinely unused files, since it has no way to distinguish "unused" from
"used but undocumented" — it only sees what was touched during the probe. This means Syft/Grype
become partially blind on the *slimmed* image: a package can still be present and functional
while no longer being detected (confirmed on `flask` and `flask-redis`, see their
`comparison.md`). The size reduction is real; the vulnerability/component reduction is partly a
detection artifact, not a security improvement.

**Recommendation:** generate the SBOM and run vulnerability scanning against the **original**
image, before minimization — that is the accurate, auditable security record. The **slim**
image should be the one deployed to production (for its size/attack-surface benefits), but its
own SBOM/scan results should not be relied upon as a complete picture of what it contains.

```
build original → SBOM + vulnerability scan (security decisions made here) → slim → deploy slim image
```

## 6. Excluded Cluster: Rust/WASM (out of scope)

The Rust/WASM cluster (`wasmedge-mysql-nginx`, `wasmedge-kafka-mysql`, and — while
technically native Rust, not WASM — `react-rust-postgres`'s backend) was attempted and
excluded after hitting two independent, concrete blockers, tested directly rather than
assumed:

1. **The WASM examples cannot be run in this environment at all.** `wasmedge-mysql-nginx`'s
   production image is `FROM scratch` + a `.wasm` binary, requiring the
   `io.containerd.wasmedge.v1` container runtime (`compose.yaml`: `runtime:
   io.containerd.wasmedge.v1`). This Docker installation only has `runc` registered
   (`docker info` confirms no wasmedge runtime), and the host has no standalone `wasmedge`
   CLI either. `docker-slim` itself would need to start a container from this image to run
   its dynamic analysis, which is not possible here — not a pipeline limitation, an
   environment/tooling one.
2. **Both Rust examples attempted fail to even build**, independent of (1).
   `wasmedge-mysql-nginx/backend/Cargo.toml` and `react-rust-postgres/backend/Cargo.toml`
   both ship without a committed `Cargo.lock` (unlike the Node examples, which commit
   `package-lock.json`). Building today resolves current crates.io dependency versions,
   several of which now require Rust's "edition 2024" — unsupported by the Rust toolchains
   pinned in these Dockerfiles (`rust:1.64`, `rust:buster`/Cargo 1.79). This is dependency
   drift in the upstream vendored examples, not something introduced by this pipeline.

**Conclusion:** the Rust/WASM cluster is excluded from this project's minimization results.
This is itself a valid finding worth reporting: not every example in a multi-year-old
reference repository remains buildable/runnable without non-trivial intervention (pinning a
working dependency set, or provisioning a WasmEdge-enabled container runtime), and
attempting a fix was judged out of scope for what this pipeline is meant to demonstrate.
Final example coverage: **7 examples across 6 technology clusters** (Python ×2, PHP, Node,
Java, Go, .NET) — see `artifacts/*/comparison.md` for each.
