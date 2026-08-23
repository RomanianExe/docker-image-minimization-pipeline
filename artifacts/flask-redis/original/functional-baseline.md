# Functional Baseline — `flask-redis` example (Stage 2)

## Build verification
- Built via `pipeline/build.sh flask-redis original` (`docker build --target builder`),
  same approach validated against `docker compose build` for the `flask` example.
- Image tag: `dip-flask-redis:original`, real size (per `docker inspect .Size`): 25.0MB.

## Services & communication
- Two services: `web` (custom build, Flask) and `redis` (prebuilt `redislabs/redismod`).
- `web` depends on `redis` (compose `depends_on`) and connects to it by hostname `redis`
  on port 6379 (`Redis(host='redis', port=6379)` in `app.py`).
- Verified the dependency is honored at the pipeline level via `pipeline/deps.sh`
  (starts/stops the `redis` container) and `--link` when running/probing `web`.

## Exposed functionality
- Container listens on port 8000.
- Single HTTP route: `GET /` → `200 OK`, body `This webpage has been viewed N time(s)`,
  where `N` is a counter incremented in Redis (`redis.incr('hits')`) on every request.
- This route exercises the full call chain: HTTP request → Flask handler → Redis
  read/write → HTTP response. It is not a static response, so it validates real
  service-to-service communication, not just "the web container started".

## Functionality that must be preserved after minimization
- Container starts and stays running.
- Port 8000 open and accepting connections.
- `GET /` returns 200 with a body matching `This webpage has been viewed ... time(s)`
  AND the counter must actually increment across repeated requests (proves Redis
  read/write still works, not just that Flask returns a canned string).
- The Redis client library (`redis` pip package) and its runtime dependencies must
  remain functional after minimization.

## Test coverage
- `tests/generic/container_up.sh` — container `running` state check.
- `tests/generic/http_health.sh` — `GET /` returns 2xx and body contains expected substring.
- `tests/specific/flask-redis/counter_increment.sh` — issues two requests and asserts the view
  counter strictly increases, proving Redis read/write happens on *every* request (a static or
  cached response would pass the substring check above but fail this one).
- `tests/specific/flask-redis/test.sh` — orchestrates all three against the `web` container.
- Result against `dip-flask-redis:original`: **PASS**.

## Baseline artifacts (this directory)
- `sbom.json` — Syft SBOM, 82 components identified.
- `vulns.json` — Grype scan, 32 vulnerabilities (9 High, 19 Medium, 3 Low, 1 Negligible).
- `metrics.json` — consolidated metrics for before/after comparison.
