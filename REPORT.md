# Report: Docker Image Minimization with Slim Toolkit

## Abstract

This project evaluates the reduction of Docker image size for examples from
[Docker Awesome Compose](https://github.com/docker/awesome-compose) using Slim
Toolkit. Each result compares the image that the Compose example actually
ships with a minimized version. A result is accepted only when the same
functional test suite passes before and after minimization.

The project produced 34 validated results: all 25 buildable examples and nine
prebuilt-image examples. Across those results, total normalized image size fell
from 14.68 GB to 7.35 GB, a 49.9% reduction. The median reduction is 63.6%
across the 33 examples other than the already-`scratch` baseline.

## Objective

The objective was to determine whether Slim Toolkit can reduce container-image
size while retaining the observable behaviour of applications from the Awesome
Compose collection.

The comparison uses the actual Compose-built image as the baseline rather than
a hand-written replacement Dockerfile. This keeps the measurement aligned with
what each example really deploys.

## Methodology

For every supported example, the pipeline performs the following steps:

1. Build the original image through the example's Compose configuration, or
   pull and re-tag the upstream image for a prebuilt example.
2. Start the required stack and run the example-specific functional test suite.
3. Generate an SBOM with Syft, scan the image with Grype, and measure normalized
   OCI uncompressed layer bytes with Skopeo.
4. Minimize the original image with Slim Toolkit, using HTTP probes and any
   example-specific paths or requests needed during dynamic analysis.
5. Start the minimized image with the same dependencies and run the same
   functional test suite again.
6. Generate the minimized-image SBOM and scan, then write a comparison artifact.

The vendored Awesome Compose examples are not modified. Pipeline-specific
configuration, Compose overrides, and tests live outside `vendor/`.

### Why Skopeo is used for image size

Docker's `image inspect .Size` field is not a stable cross-host measurement:
its reported semantics can differ between the classic Docker image store and
the containerd image store. `docker save` is not a substitute because its
archive size includes serialization and metadata overhead.

The pipeline instead uses Skopeo to export the local image to an OCI layout for
the host platform, normalize each layer to an uncompressed OCI tar layer, and
validate the manifest descriptors, blob sizes, and SHA-256 digests. The reported
size is the sum of those validated uncompressed layer descriptors. This defines
one reproducible metric — cumulative uncompressed OCI layer bytes — regardless
of the local Docker image-store backend. Temporary OCI blobs are discarded; the
recorded OCI index and manifest metadata remain as compact measurement evidence.

## Scope

| Category | Count | Status |
|---|---:|---|
| Awesome Compose entries inventoried | 39 | Complete inventory |
| Configured for the pipeline | 37 | Buildable and prebuilt examples |
| Validated original-to-slim comparisons | 34 | Included in aggregate results |
| Baseline-only examples | 3 | Documented, not counted as slim results |
| WasmEdge examples | 2 | Excluded: required host runtime unavailable |

All 25 examples that ship a Dockerfile completed the full pipeline. The three
baseline-only cases are prebuilt images for which Mint cannot preserve the
workload's runtime contract: `gitea-postgres`, `plex`, and `wireguard`. They are
recorded as diagnosed limitations rather than presented as successful results.

## Aggregate Results

| Metric | Original | Slim | Change |
|---|---:|---:|---:|
| Image size | 14.68 GB | 7.35 GB | **-49.9%** |
| SBOM components | 13,205 | 5,185 | **-60.7%** |
| Grype findings | 18,174 | 2,020 | **-88.9%** |

All 34 validated comparisons report passing functional tests for both the
original and the minimized image. The detailed, generated table is available in
[`artifacts/summary.md`](artifacts/summary.md).

## Representative Cases

| Example | Original | Slim | Change | Why it matters |
|---|---:|---:|---:|---|
| `nginx-golang-mysql` | 348.12 MB | 8.11 MB | **-97.7%** | Largest reduction; the Compose configuration ships a large Go builder-stage image. |
| `flask-redis` | 77.64 MB | 28.74 MB | **-63.0%** | Near the project median and exercises an application with a Redis dependency. |
| `nextcloud-postgres` | 1558.18 MB | 1604.99 MB | **+3.0%** | Correctness-first result: a post-Mint repair restores the upstream empty-volume initialization contract. |
| `traefik-golang` | 6.24 MB | 6.24 MB | **+0.02%** | Negative result: the shipped image is already `FROM scratch`, so Slim has no useful content to remove. |

The `traefik-golang` result is intentionally retained. It demonstrates the
boundary of the technique: Slim is valuable for oversized images, but it cannot
improve an image that is already close to a minimal static binary.

## Interpretation

Slim Toolkit is most effective when a Compose example ships development tools,
package managers, build dependencies, or unused runtime files. The largest
reductions occur in examples that build from full language toolchain images.

The results also show that choosing the correct final stage of a multi-stage
Dockerfile can be a larger optimization than applying Slim afterwards. Slim
should therefore complement, not replace, good Dockerfile design.

## Validity and Limitations

- Functional correctness is demonstrated only for the paths exercised by the
  tests. Dynamic minimization can remove files used by untested code paths, so
  the test suite defines the supported behaviour of each published result.
- Image size is measured as normalized OCI uncompressed layer bytes, independent
  of the local Docker image-store backend. SBOM component counts and vulnerability
  counts require caution: Slim can remove package metadata, which reduces what
  Syft and Grype can detect without necessarily removing all associated risk.
  The vulnerability reduction is therefore an upper bound, not proof of an
  equivalent security improvement.
- Three prebuilt examples have a successful original baseline but no validated
  slim result. Their diagnosed causes are documented in
  [`docs/methodology.md`](docs/methodology.md).
- Measurements were produced with Docker 29.7.2, Docker Compose 5.5.0, Slim
  Toolkit 1.41.8, Syft 1.51.0, Grype 0.117.0, and Skopeo 1.13.3. See the main
  [`README.md`](README.md) for setup details.

## Reproduction and Evidence

After installing the required tools, run one example end to end:

```bash
pipeline/run-pipeline.sh flask
```

For each example, `artifacts/<example>/` contains the original and minimized
SBOMs, vulnerability scans, metrics, Slim report, security profiles, and the
final comparison. The image references and per-image manifests are maintained
in the sibling `slimmed-images` repository.

## Conclusion

The project demonstrates that Slim Toolkit can substantially reduce the size of
many Compose-based application images while preserving tested behaviour. The
median validated reduction is 63.6%, with the best result reaching 97.7%.
At the same time, the retained no-benefit case, the Nextcloud correctness-first
size increase, and the three documented Mint limitations show that the evaluation
reports limitations honestly rather than treating every attempt as a success.
