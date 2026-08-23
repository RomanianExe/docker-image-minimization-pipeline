# Functional Baseline — `sparkjava` example (Stage 2)

## Build notes
- Same "real final stage" pattern as `react-nginx`: the Dockerfile's final,
  unnamed stage (`eclipse-temurin:17-jre-focal`, running the fat jar built by
  Maven in the `build` stage) is the one `compose.yaml` actually builds (no
  `target:` set there). `pipeline.env` sets `DOCKERFILE_TARGET=` (empty).
- Build context: `vendor/awesome-compose/sparkjava/sparkjava` (the subdirectory
  containing the Dockerfile, `pom.xml`, and `src/`).
- Image tag: `dip-sparkjava:original`, real size (`docker inspect .Size`): 97.44MB.

## Exposed functionality
- Container listens on port 8080.
- Single route: `GET /` → `200 OK`, body `Hello from Docker!` (plain text,
  returned directly from the SparkJava route handler in `App.java`).

## Functionality that must be preserved after minimization
- Container starts and stays running (JVM boots, SparkJava's embedded Jetty
  server starts listening).
- Port 8080 open and accepting connections.
- `GET /` returns 200 with body `Hello from Docker!`.

## Test coverage
- `tests/generic/container_up.sh` — container `running` state check.
- `tests/generic/http_health.sh` — `GET /` returns 2xx and body contains expected substring.
- `tests/specific/sparkjava/test.sh` — orchestrates both against the `sparkjava` container.
- Result against `dip-sparkjava:original`: **PASS**.

## Baseline artifacts (this directory)
- `sbom.json` — Syft SBOM, 170 components identified (JVM/OS packages from the
  Ubuntu-focal-based `eclipse-temurin:17-jre-focal` image, plus Java libraries
  bundled inside the fat jar itself — SparkJava, Jetty, SLF4J, etc.).
- `vulns.json` — Grype scan, 462 vulnerabilities (28 High, 281 Medium, 141 Low,
  12 Negligible). This is the first JVM-based example in the pipeline; the count
  is notably higher than the Python/Alpine or Node/nginx-alpine examples, driven
  by the Ubuntu-focal base plus the number of bundled Java libraries in the
  fat jar that Syft can enumerate (unlike compiled Go/Rust binaries).
- `metrics.json` — consolidated metrics for before/after comparison.
