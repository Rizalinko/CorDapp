# Part 5: CI/CD Pipeline

Three GitHub Actions pipelines cover the full lifecycle from source change to
production deployment.

| Pipeline | Workflow file | Trigger |
|----------|--------------|---------|
| A: Docker images | `.github/workflows/docker-image.yml` | push to main, v* tags, PRs |
| B: Helm charts | `.github/workflows/helm-chart.yml` | push to main, v* tags, PRs |
| C: Deployment | `.github/workflows/deploy.yml` | docker-image completion, workflow_dispatch |

## Branch strategy and environment mapping

```
branch / tag          pipeline behaviour
--------------------  -------------------------------------------------------
pull_request          A: lint + build + scan + smoke test (no push)
                      B: lint + template validate + helm-docs check (no push)

main (merge)          A: lint + build + scan + smoke + push tag 4.14.0-{sha7}
                      B: lint + validate + docs + package + push to OCI
                      C: auto-deploy to staging using the sha7 tag

v* tag (e.g. v1.0.0)  A: lint + build + scan + smoke + push tags 4.14.0 + latest
                      B: lint + validate + docs + package + push to OCI
                      (no automatic deploy; use workflow_dispatch for production)
```

### Image tag scheme

| Git event | jar-image tags | node-image tags |
|-----------|---------------|-----------------|
| push to main | `4.14.0-{sha7}`, `dev` | `4.14.0-{sha7}`, `dev` |
| push of `v*` tag | `4.14.0`, `latest` | `4.14.0`, `latest` |

The `4.14.0` prefix is the Corda version declared in `env.CORDA_VERSION` in the workflow.
The git tag (`v1.0.0`) represents a platform release, not the Corda version.

### Promotion to production

Production deployment is always manual:

1. Verify the staging deployment is healthy (`kubectl -n corda get pods`).
2. Go to **Actions → deploy → Run workflow**, pick `environment: production`,
   and enter the image tag that is running in staging (e.g. `4.14.0-abc1234`).
3. The GitHub `production` environment enforces required-reviewer approval before
   the job runs. After approval, `helmfile -e production apply` deploys the
   `values.prd.yaml` overlays (PostgreSQL, managed-csi-premium storage, 4Gi RAM).

## Pipeline A: Docker images

```
lint (hadolint + shellcheck)
  |
  v
build-scan-smoke (builds images, Trivy scan, docker-compose smoke test)
  |
  v (only on main or v* tag)
release
  |-- push jar-image to GHCR
  |-- push node-image to GHCR (JAR_IMAGE pinned by digest from the jar push)
  |-- cosign sign both images (keyless, Sigstore OIDC)
```

**Why pin `JAR_IMAGE` by digest in the node-image build?**
The node-image `build-args` passes `JAR_IMAGE=ghcr.io/acmecorp/corda-jar@sha256:...`
(the digest output of the jar-image push step). This guarantees the node-image
references the exact bytes just pushed, not a tag that could be overwritten between
the two build steps.

**Why cosign keyless signing?**
Keyless signing uses a short-lived certificate issued by Sigstore's Fulcio CA,
anchored to the GitHub Actions OIDC token. No private key is stored anywhere.
Verifiers can check the signature with `cosign verify --certificate-identity-regexp
'https://github.com/acmecorp/.*' --certificate-oidc-issuer 'https://token.actions.githubusercontent.com'
ghcr.io/acmecorp/corda-node@sha256:...`.

## Pipeline B: Helm charts

```
lint-template-validate    helm-docs check
          |                     |
          +----------+----------+
                     v (only on main or v* tag)
               package-push
                 |-- helm package corda-node
                 |-- helm push to oci://ghcr.io/acmecorp/charts
                 |-- helm package corda-bootstrap
                 |-- helm push to oci://ghcr.io/acmecorp/charts
```

Chart versions come from `version:` in each `Chart.yaml`. Bump that field when
releasing a new chart version; the OCI registry keeps all previous versions.

## Pipeline C: Deployment

```
docker-image workflow completes on main
          |
          v (automatic)
  staging job (environment: staging)
          |-- helmfile apply (default environment, base values.yaml)
          |-- IMAGE_TAG passed via environment variable
          |-- kubectl get pods to verify

workflow_dispatch with environment=production
          |
          v (manual, requires GitHub environment reviewer approval)
  production job (environment: production)
          |-- helmfile -e production apply (adds values.prd.yaml overlays)
          |-- IMAGE_TAG from workflow_dispatch input
          |-- kubectl get pods to verify
```

`IMAGE_TAG` is passed to helmfile as a shell environment variable. `helmfile.yaml`
reads it with `{{ env "IMAGE_TAG" | default "" }}` and injects it as an inline
values override for all three node releases. An empty tag defaults to the chart's
`appVersion`, which means the base `corda-node` image without CorDapp JARs.

## Secret management

| Secret | Where stored | How used |
|--------|-------------|----------|
| `GITHUB_TOKEN` | GitHub automatic | GHCR image push, helm OCI login, cosign OIDC |
| `KUBECONFIG_STAGING` | GitHub Actions secret (repo) | base64-decoded to `/tmp/kubeconfig` in the staging job |
| `KUBECONFIG_PROD` | GitHub Actions secret (environment: production) | base64-decoded to `/tmp/kubeconfig` in the production job |

`KUBECONFIG_STAGING` is a repo-level secret (available to any job). `KUBECONFIG_PROD`
is scoped to the `production` GitHub environment so it is only available after
the required-reviewer gate passes. Both are written to `/tmp/kubeconfig` and the
`KUBECONFIG` env var is set to that path. The file is never committed and is
discarded when the runner terminates.

Node passwords (`rpc-password`, `keystore-password`, `truststore-password`) live
in Kubernetes Secrets created by the bootstrap job. They are not present in any
workflow secret; the workflow only needs cluster access to run helmfile.

## Idempotency and reproducibility

**Image builds:** Docker BuildKit with the GHA cache (`type=gha`) ensures
byte-for-byte identical layers on rebuilds of the same commit. The `jar-image`
is pinned to a verified SHA-256 checksum for each Corda JAR (see `jar-image/Dockerfile`).
The node-image references the jar-image by digest so the build graph is fully
pinned.

**Helm releases:** `helmfile apply` is idempotent. It computes the diff between
the current release state and the desired state and only upgrades releases that
have changed. The bootstrap job inside `corda-bootstrap` checks for existing
`network-parameters` before re-running the bootstrapper, so re-applying is safe.

**Deployments:** `IMAGE_TAG` is always an immutable reference (sha7 tag or
digest-pinned). Rolling back means re-running the deployment workflow with the
previous tag. There is no mutable `latest` in the deploy path.

## Local reproduction

Any step that runs in CI can be reproduced locally with the same tools:

```bash
make lint           # equivalent to the lint job in both A and B
make build-node     # equivalent to the build step in build-scan-smoke
make compose-up     # equivalent to the smoke test
make lint-helm      # equivalent to lint-template-validate
make docs-helm      # equivalent to the helm-docs check
```

The `release` and `package-push` jobs require GHCR credentials and are
not intended for local use. Use `docker push` and `helm push` manually if needed.
