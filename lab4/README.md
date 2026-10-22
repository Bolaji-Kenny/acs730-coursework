# Lab 4: Docker fundamentals and a real CI pipeline

A small Flask app (`app.py`) containerised with Docker and built, tested, cached and published by GitHub Actions.

## Image size: before and after

| Image | Dockerfile | Base image | Size |
|---|---|---|---|
| `lab4-naive` | `Dockerfile.naive` | `python:3.11` (full), `COPY . .` before install, runs as root, shell-form `CMD` | 1.12 GB |
| `lab4:1.0` | `Dockerfile` | `python:3.11-slim`, dependencies installed before the source copy, `--no-cache-dir`, non-root `appuser`, exec-form `CMD`, `.dockerignore` | 141 MB |

The shipped image is about 8x smaller (1.12 GB to 141 MB, roughly 87% less). The build context also shrank from 940 B to 181 B once `.dockerignore` was added. Evidence: `evidence/image-sizes.png`.

## CI timings: three runs for each cache

Per-step durations read from the Actions API for three runs of the same code.

| Step | Run 1: baseline (no cache) | Run 2: cache miss | Run 3: cache hit |
|---|---|---|---|
| pip: `Install dependencies` (Python 3.11) | 2 s | 2 s | 2 s |
| pip: `Install dependencies` (Python 3.12) | 2 s | 2 s | 3 s |
| pip: `setup-python` step (3.12) | 0 s | 1 s | 4 s |
| Docker: `Build image` | 6 s | 21 s | 5 s |

Each miss and hit was confirmed in the step's own log, not just from timings. Run 2 shows only `Cache saved with the key` (a true miss). Run 3 shows `Cache hit` / `Cache restored successfully` for pip and `CACHED` for the Docker layers (a true hit).

**pip cache: not worth it here.** Flask and pytest install in about 2 s anyway, so a hit saved nothing. Restoring the cache even made the Python 3.12 job slower (setup-python went from 0 s to 4 s). It would pay off with large dependencies (numpy, pandas) and not for this app.

**Docker layer cache: marginal, not worth it for this app.** A hit took 5 s against 6 s uncached, so about 1 s saved, while the first run with the cache cost 21 s because the layers have to be exported. The base image pulls fast and the dependency layer is tiny. It would be worth it with a slow, heavy dependency layer that rarely changes.

## Why the image goes to GHCR tagged by commit SHA

A SHA tag is immutable and unambiguous: every image can be traced back to the exact commit that produced it, a deploy can be rolled back to a known SHA, and two builds can never silently overwrite each other the way a moving tag like `latest` does. GHCR is used because it is next to the code, authenticates with the workflow's own `GITHUB_TOKEN` (no stored cloud keys), and the `publish` job gets `packages: write` only for itself, with `contents: read` kept alongside it. Evidence: `evidence/ghcr-package.png`.

## Pipeline design

- `test` runs a matrix over Python 3.11 and 3.12 via the composite action `.github/actions/python-deps` (steps reused inside a job on the same runner).
- `build` calls the reusable workflow `.github/workflows/docker-build.yml` (a whole job, with its own runner, inputs and outputs, reusable from other pipelines).
- `smoke` downloads the image artifact that `build` uploaded and tests that exact image.
- `publish` pushes to GHCR on `main` only, never on pull requests.
- `summary` runs with `if: always()`, writes a step summary, and fails if any upstream job failed, so a failure is never hidden.
- `summary` is a required status check on `main`; a failing test disables the merge button. Evidence: `evidence/required-check.png`, `evidence/ci-graph.png`.

## GitHub Actions vs AWS-native CI/CD

For building, testing and publishing this app, I recommend GitHub Actions. The code, pull requests and required checks are already on GitHub, the pipeline needs no cloud credentials at all (the Week 4 build uses none), and workflows are easy to version, review and reuse. AWS-native tools (CodeBuild, CodePipeline, ECR) fit better when the pipeline has to reach private AWS resources inside a VPC, when IAM roles and audit trails must be the single source of control, or when an organisation requires everything to stay inside AWS. The sensible split is Actions for CI, plus AWS-native or OIDC-based roles only for the steps that deploy into AWS.
