# Functional Baseline — `traefik-golang` example (Stage 2)

## Scope decision: backend only, no docker.sock mount
`compose.yaml`'s `frontend` service (`traefik:2.6`) discovers `backend` via
Docker labels and requires `/var/run/docker.sock` mounted inside the
`frontend` container to talk to the Docker daemon. Mounting the host's Docker
socket into a test-harness container is a security-sensitive operation (it
grants effective root-equivalent control over the host's Docker daemon), so
this was deliberately skipped. `traefik` is also a vendored, unmodified image
— not part of the minimization scope, same reasoning already applied to
`redis`/`mariadb`/`mssql` dependency images in prior examples. `backend` is
tested directly on its own port (`80`, mapped to host `8088`).

## New pattern: already-minimal `FROM scratch` final stage
`backend/Dockerfile` is multi-stage: `build` (golang:1.18, static binary via
`CGO_ENABLED=0`) → `dev-envs` (adds git/Docker CLI tooling, unused stage) →
a final **unnamed** `FROM scratch` stage that copies only the compiled binary.
Same "free minimization" pattern already observed on `nginx-golang`, but here
pushed further: `FROM scratch` (empty base, not even a minimal distro) plus a
single static Go binary. `pipeline/build.sh` omits `--target`, so this final
scratch stage is what gets built as `dip-traefik-golang:original` — 3.56MB,
just the binary and nothing else.

## Build verification
- Built via `pipeline/build.sh traefik-golang original` (no `--target`).
- Image tag: `dip-traefik-golang:original`, real size: 3.56MB (`docker inspect
  .Size`).

## Exposed functionality
- `GET /` → `200 OK`, fixed ASCII-art banner containing "Hello from Docker".
- `main.go`'s `handler()` also prints the request's raw query string
  (`r.URL.RawQuery`) to container stdout via `fmt.Println` — a second,
  separately observable behavior not visible in the HTTP response itself.

## Test coverage
- `tests/generic/container_up.sh` — container `running` state check.
- `tests/generic/http_health.sh` — `GET /` returns 200 and contains "Hello
  from Docker".
- `tests/specific/traefik-golang/test.sh` additionally sends a unique marker
  as a query string (`?probe=<marker>`) and asserts it appears in `docker
  logs`, directly exercising `r.URL.RawQuery` handling — the only other
  observable code path in this app, and one the static-content check alone
  would never catch a regression in.
- Result against `dip-traefik-golang:original`: **PASS**.

## Baseline artifacts (this directory)
- `sbom.json` — Syft SBOM, 2 components (essentially just the Go binary
  itself; scratch base has nothing else to catalog).
- `vulns.json` — Grype scan, 40 vulnerabilities (2 Critical, 23 High, 14
  Medium, 1 Low) — all attributable to the Go toolchain/stdlib version baked
  into the static binary, not to any OS packages (there are none).
- `metrics.json` — generated automatically by `pipeline/run-pipeline.sh`.
