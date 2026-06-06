# Part 4: CorDapp Deployment

Dockerfile: [`docker/cordapp-image/Dockerfile`](../docker/cordapp-image/Dockerfile)
CI workflow: [`.github/workflows/cordapp.yml`](../.github/workflows/cordapp.yml)

## Delivery mechanism

CorDapp JARs are deployed as an additional Docker image layer on top of the
existing `corda-node` runtime image. The layering is identical in structure
to the `jar-image` to `node-image` relationship established in Part 1:

```
ghcr.io/acmecorp/corda-jar:4.14.0
         |
         v  (adds JRE + Corda runtime, scripts, JDBC driver)
ghcr.io/acmecorp/corda-node:4.14.0
         |
         v  (adds CorDapp JARs in /opt/corda/cordapps-baked/)
ghcr.io/acmecorp/corda-node:4.14.0-cordapp-1.0.0
```

The node StatefulSet is pointed at the combined tag. No init containers, no
volume mounts for JARs, no runtime downloads.

## Why this approach

| Property | Artifact image |
|----------|---------------|
| All nodes run identical JAR bytes | Image tag is the single source of truth |
| Rollback | Revert the values file commit, run helmfile apply |
| Air-gap compatible | No network access at pod startup |
| Auditable | Trivy scans the image in CI before it reaches any node |
| Consistency | A single `image.tag` value covers all three releases |

## How the node discovers baked CorDapps

`generate-config.sh` emits `cordappDirectories` with two entries on every start:

```
cordappDirectories = [ "/var/lib/corda/cordapps", "/opt/corda/cordapps-baked" ]
```

`/var/lib/corda/cordapps` is on the PVC and accepts JARs at runtime (dev or
hot-loading). `/opt/corda/cordapps-baked` is in the image layer and is where
the artifact image places the production JARs. Corda scans both paths on startup.

## Building the cordapp-image

Place your CorDapp JARs in `docker/cordapp-image/cordapps/` then:

```bash
make build-cordapp
```

The local build sequence is:

```
make build-jar        # certified JRE + Corda jars
make build-node       # node runtime (entrypoint, scripts, JDBC driver)
make build-cordapp    # + CorDapp JARs
```

`build-cordapp` fails immediately if no JAR is found in `cordapps/`, preventing
an accidental empty-image push.

## Image tag scheme

Every cordapp-image tag encodes both the Corda version and the CorDapp version:

```
{registry}/corda-node:{corda-version}-cordapp-{cordapp-version}
example:   ghcr.io/acmecorp/corda-node:4.14.0-cordapp-1.3.0
```

The `{corda-version}` segment identifies the base `corda-node` layer. The
`{cordapp-version}` segment identifies the CorDapp release. Both are readable
from the tag without inspecting the image.

## CI workflow

`.github/workflows/cordapp.yml` is a `workflow_dispatch` workflow with three inputs:

| Input | Purpose |
|-------|---------|
| `cordapp_version` | CorDapp semver (e.g. `1.3.0`) |
| `node_tag` | Base `corda-node` tag to build on (e.g. `4.14.0`) |
| `cordapp_jar_url` | Direct download URL for the CorDapp JAR |

Steps in order:

1. hadolint lints `docker/cordapp-image/Dockerfile`.
2. The CorDapp JAR is downloaded from `cordapp_jar_url`.
3. `docker/cordapp-image` is built with `NODE_IMAGE=corda-node:{node_tag}` and pushed to GHCR.
4. Trivy scans the pushed image. Findings are uploaded as a SARIF report.
5. `yq` writes the new combined tag into `image.tag` in all three deploy values files.
6. The workflow commits and pushes the updated values. The next `helmfile apply` picks them up.

Integrating with an artifact registry: replace the `curl` in the "Download CorDapp JAR" step
with whatever command fetches the JAR from your Nexus, Artifactory, or GHCR packages endpoint.

## Deploying a new CorDapp version

1. Publish the CorDapp JAR to your artifact registry.
2. Trigger `.github/workflows/cordapp.yml` from the GitHub Actions UI with the new version and JAR URL.
3. The workflow pushes the new image and commits the updated `image.tag` to the three deploy values files.
4. Run `helmfile apply` (or wait for your deploy pipeline to detect the commit):
   - Each node StatefulSet detects the new image tag and replaces the pod.
   - On the new pod, `/opt/corda/cordapps-baked/` contains the updated JAR.
   - Corda loads it from `cordappDirectories` on startup.

## Rollback

1. Revert the `image.tag` commit in `deploy/*/values.yaml` (or set `image.tag` to the previous tag).
2. Run `helmfile apply`. Nodes restart with the previous image.

Because the values change is a plain git commit, rollback is `git revert` plus one apply.

## CorDapp version compatibility

Corda enforces CorDapp compatibility via `targetPlatformVersion` and
`minimumPlatformVersion` declared in each CorDapp's JAR manifest.

Rules that affect deployment on a bootstrapped private network:

- All nodes in a transaction must have the same CorDapp installed. Deploying a
  new JAR to all nodes before any node initiates a flow using the new code is
  sufficient for backwards-compatible changes (new flows, new commands).
- Contract code changes that alter state or verification logic require a Corda
  contract upgrade flow or an explicit ledger migration agreed by all counterparties.
- Since all three nodes use the same image tag (committed atomically by CI), there
  is no window where nodes hold different CorDapp versions.

## Local development without a full image rebuild

For rapid dev iteration, copy a JAR directly to the PVC:

```bash
kubectl -n corda cp my-cordapp.jar notary-corda-node-0:/var/lib/corda/cordapps/
kubectl -n corda exec notary-corda-node-0 -- ls /var/lib/corda/cordapps/
```

Corda picks it up on the next node restart. This path (`/var/lib/corda/cordapps`)
is separate from `/opt/corda/cordapps-baked`, so the production image is unaffected.
