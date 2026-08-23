# Before/After Comparison — `sparkjava` example (Stage 5)

## Metrics summary

| Metric | Original (`dip-sparkjava:original`) | Slim (`dip-sparkjava:slim`) | Change |
|---|---|---|---|
| Image size (real, `docker inspect .Size`) | 97.44 MB | 53.96 MB | **-44.6%** |
| SBOM components (Syft) | 170 | 20 | -150 |
| Vulnerabilities (Grype) | 462 (28 High / 281 Medium / 141 Low / 12 Negligible) | 44 (15 High / 19 Medium / 10 Low) | -418 |
| Functional tests | PASS | PASS | no regression |

## First JVM example: smallest minimization ratio observed so far
Only a **1.81x** reduction (vs. 5-6x for the Python/Node examples). The JVM
runtime (`eclipse-temurin:17-jre-focal`) needs a large portion of its own files
(class libraries, `libjvm.so`, character encodings, etc.) just to start and run
*any* Java program — Slim's dynamic analysis correctly identifies most of this
as genuinely used, so there is much less "dead weight" to remove compared to,
say, a Python interpreter or a static Nginx binary. This is an expected,
technology-driven result, not a pipeline issue.

## New observation: jar-embedded dependency metadata survives, unlike OS package metadata
Unlike every previous example (where post-slim SBOM component counts dropped to
near zero), `sparkjava` still shows **20 components** after minimization instead
of ~0-4. This is because the application is shipped as a single fat `app.jar`
(built by `mvn assembly:single`), and Slim keeps that jar file **entirely intact**
(it's one file that's read as a whole to run the app, so nothing inside it looks
"unused" to Slim's file-level analysis). Syft can still open the jar and read the
embedded `pom.xml`/`META-INF` metadata for SparkJava, Jetty, SLF4J, etc. bundled
inside it. What Slim did strip is the **OS-level** package metadata (`dpkg` on the
Debian/Ubuntu-focal base), same pattern as the other examples — that's most of
the observed reduction (some JVM/OS-level components are gone), not a removal of
the Java library metadata itself.

**Implication for the "SBOM visibility loss" caveat (docs/methodology.md §5):**
this shows the visibility loss is specifically about *OS package manager*
metadata (`dpkg`, `apk`), not about all forms of dependency metadata — a
single-file, self-describing artifact like a fat jar keeps its own dependency
information readable even after minimization. Worth calling out as a nuance:
the caveat applies unevenly depending on how a runtime packages its dependencies.

## Functional validation
- `tests/generic/container_up.sh` + `tests/generic/http_health.sh` (via
  `tests/specific/sparkjava/test.sh`) both pass against `dip-sparkjava:slim`:
  `GET /` returns `200 OK` with body `Hello from Docker!`, confirming the JVM
  still boots and SparkJava's embedded Jetty server still serves requests
  correctly after minimization.
