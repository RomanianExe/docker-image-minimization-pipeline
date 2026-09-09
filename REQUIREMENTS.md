# Requirements

This document lists the host-side tools required to run the Docker Image
Minimization Pipeline. Run the commands from the repository root on a Linux or
WSL environment with access to a running Docker daemon.

## Required for the full pipeline

| Tool | Required capability | Used for |
|---|---|---|
| Docker Engine and CLI | build, pull, run, inspect, volumes, networks, and `docker cp` | Build and run original/Slim images and their dependencies |
| Docker Compose plugin | `docker compose` | Build and run each example through its effective Compose configuration |
| Docker Buildx plugin | `docker buildx` | BuildKit-backed Compose builds and post-Mint wrapper images |
| Mint / Slim Toolkit | `mint` | Dynamic analysis and image minimization |
| Syft | `syft` | Generate SPDX/Syft JSON SBOMs |
| Grype | `grype` and `jq` | Generate and validate vulnerability-scan JSON |
| Skopeo | `skopeo` | Export and validate OCI layouts for the backend-independent size metric |
| Python 3.8+ | `python3` | Metrics, comparison, summary, and publishing metadata scripts; standard library only |
| Bash, curl, jq | `bash`, `curl`, `jq` | Pipeline orchestration, HTTP functional tests, and JSON validation |
| Standard Linux userland | `mktemp`, `grep`, `sed`, `awk`, `find`, `sort`, `comm`, `cut`, `head`, `wc`, `sha256sum` | Functional tests and artifact validation |

The project records image size as **normalized OCI uncompressed layer bytes**.
Skopeo is therefore mandatory, not an optional inspection tool. The pipeline fails
closed if OCI export, descriptor validation, or layer normalization fails.

## Recommended versions

The currently recorded toolchain is:

| Tool | Version recorded in the project |
|---|---|
| Docker Engine | 29.7.2 |
| Docker Compose | v5.5.0 |
| Mint | 1.41.8 |
| Syft | 1.51.0 |
| Grype | 0.117.0 |
| Skopeo | 1.13.3 |
| Python | 3.14 (3.8+ supported by project scripts) |

Exact versions are useful for reproducing a recorded run, but Docker image inputs
are digest-pinned and the pipeline itself does not require these exact host versions.
Grype findings can change when its vulnerability database changes; compare scans from
the same database snapshot when exact finding counts matter.

## Installation on Debian/Ubuntu or WSL

Install the system packages first:

```bash
sudo apt-get update
sudo apt-get install -y \
  bash curl jq skopeo python3 \
  coreutils findutils grep sed gawk
```

Install Docker Engine/CLI with the Compose and Buildx plugins using Docker's supported
installation method for the host. Docker Desktop's WSL integration is also suitable,
provided the Linux `docker` CLI resolves the Compose and Buildx plugins.

Install Mint, Syft, and Grype using their maintained installers or package sources. The
commands below match the setup used by this project; review downloaded installer scripts
before running them:

```bash
curl -sL https://raw.githubusercontent.com/mintoolkit/mint/master/scripts/install-mint.sh | sudo -E bash -
curl -sSfL https://get.anchore.io/syft | sudo sh -s -- -b /usr/local/bin
curl -sSfL https://get.anchore.io/grype | sudo sh -s -- -b /usr/local/bin
```

## Verify the environment

Run these checks before a first pipeline run:

```bash
docker run --rm hello-world
docker compose version
docker buildx version
mint --version
syft version
grype version
skopeo --version
python3 --version
jq --version
curl --version
```

The Docker daemon must be reachable by the current user. The project pulls base and
prebuilt images during builds, so registry access is required. Authenticate with
`docker login` when a configured image registry requires it.

## Optional publishing requirements

`pipeline/publish.sh` additionally requires:

- `git`, for recording the pipeline commit and checking worktree state;
- permission to write the sibling `../slimmed-images` repository;
- registry credentials when `--push` is requested; and
- a `docker-slim` compatibility command in addition to `mint`, because
  `pipeline/manifest.py` records that command's version in published manifests.

The normal build/minimize/test/compare pipeline invokes `mint`; it does not require
publishing credentials or a Git remote.
