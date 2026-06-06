# Docker image for a Corda node

## Image structure and rationale

I build **two images**, mirroring the layered approach used by R3's own Corda
Docker tooling:

| Image | Dir | Contents | Changes when… |
|-------|-----|----------|---------------|
| `corda-jar` | `docker/jar-image/` | certified JRE + verified `corda.jar` + `corda-bootstrapper.jar` | the Corda version changes (rarely) |
| `corda-node` | `docker/node-image/` | `FROM corda-jar` + entrypoint, config generator, healthcheck, JDBC driver, CorDapp dirs | the runtime/operational logic changes (often) |

Splitting them keeps the slow-moving, ~280 MB jar layer cached and shared by
every node, while the fast-moving runtime layer rebuilds quickly. The **same**
`corda-node` image runs a node (default) and the network bootstrapper (`bootstrap`
entrypoint mode), so the whole platform ships as just these two images.

### Choose of the base image

R3 publishes `corda/corda-zulu-java1.8-4.14` on Docker Hub. I evaluated it and
chose to **build my own** because:

* **Maintainability.** The official corda/corda-zulu-java1.8-4.4 image is frozen at Corda 4.4 (published ~2020)
  and no longer maintained. Corda 4.12 is the current OSS release, there is no official image for it.
* **Reproducibility.** I pin the exact `corda.jar` by SHA-256
  (verified against Maven Central's published SHA-1) and keep the base image
  under our control, so I can patch the OS/JRE on my own cadence rather than
  waiting for R3 to re-publish.
* **Non-root + minimum deps.** I add a non-root user, a minimal layout,
  and keep `curl`/`apt` out of the runtime image (download happens in a builder
  stage). The official image historically runs more tooling.
* **Ease to modify.** If AcmeCorp prefers the official image, the
  `node-image` layer (entrypoint/config/healthcheck) sits on top of it almost
  unchanged — only the `FROM` and a couple of paths move.

**Base image:** `eclipse-temurin:8-jre-jammy`. Corda OS 4.x is certified by R3
on **Azul Zulu OpenJDK 8**; Temurin 8 is a widely-mirrored, well-patched OpenJDK
8 build that is functionally equivalent for the node. For a strictly-certified
production build, set `--build-arg JRE_IMAGE=azul/zulu-openjdk:8-jre` — nothing
else changes. Pin the base by digest in production (see below).

## How the image is configured at runtime

The node base directory and the immutable distribution are deliberately
separate so a volume/PVC mount never shadows the jars:

```
/opt/corda            (immutable, baked)      /var/lib/corda      (volume/PVC)
├── corda.jar                                 ├── node.conf
├── corda-bootstrapper.jar                    ├── certificates/
├── bin/{entrypoint,generate-config,...}.sh   ├── persistence/      (H2 files)
├── drivers/postgresql.jar                     ├── cordapps/        (mounted CorDapps)
└── cordapps-baked/   (Part 4 artifact)        ├── additional-node-infos/
                                               └── logs/
```

`node.conf` is produced in one of two ways:

1. **Mounted** if `/var/lib/corda/node.conf` already exists (e.g. a Helm
   ConfigMap in Part 2, or the bootstrapper output), the entrypoint uses it
   verbatim.
2. **Generated from environment** otherwise `generate-config.sh` renders it.
   This is the single source of truth and its parameters can be mapped 1:1 to the Helm
   values in the future.

### Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `NODE_ROLE` | `node` | `node` or `notary` (adds a `notary{}` block) |
| `MY_LEGAL_NAME` | _required_ | X.500 name, e.g. `O=Node1,L=London,C=GB` |
| `P2P_ADDRESS` | `${HOSTNAME}:10200` | address peers use to reach this node |
| `P2P_PORT` / `RPC_PORT` / `RPC_ADMIN_PORT` | `10200` / `10201` / `10202` | listen ports |
| `DEV_MODE` | `true` | `false` for production (enables cert + password checks) |
| `RPC_USER` / `RPC_PASSWORD` | `corda` / _(dev default)_ | RPC credentials |
| `KEY_STORE_PASSWORD` / `TRUST_STORE_PASSWORD` | — | required when `DEV_MODE=false` |
| `DB_TYPE` | `h2` | `h2` (dev) or `postgresql` (prod) |
| `DB_HOST`/`DB_PORT`/`DB_NAME`/`DB_USER`/`DB_PASSWORD`/`DB_SCHEMA` | — | required for `postgresql` |
| `NOTARY_VALIDATING` | `false` | validating vs non-validating notary |
| `COMPATIBILITY_ZONE_URL` _or_ `DOORMAN_URL`+`NETWORK_MAP_URL` | — | production identity manager / network map |
| `JAVA_OPTS` | `-Xmx512m -XX:+UseG1GC` | JVM tuning |

### Entrypoint modes

```
entrypoint.sh node       # (default) generate config if needed, then run the node
entrypoint.sh bootstrap  # run the network bootstrapper (used by the bootstrap job)
entrypoint.sh migrate    # run DB schema migrations (required before first PG start)
entrypoint.sh config     # print the node.conf that would be generated
```

## Assumptions about node configuration

* **Ports** follow the engagement brief: P2P `10200`, RPC `10201`, RPC-admin
  `10202`. `detectPublicIp=false` (mandatory inside containers).
* **Dev networks bootstrap offline** (no doorman/network-map server). `devMode`
  uses Corda's well-known dev certificates; peer discovery is via the
  `additional-node-infos/` directory the bootstrapper distributes.
* **One node per container/pod.** Vault is H2 (dev) or external PostgreSQL
  (prod) — never co-located in the container in production.
* **CorDapps** load from `cordapps/` (mounted) and `cordapps-baked/` (the Part 4
  artifact image). The PostgreSQL JDBC driver is provided via `jarDirs`.

## Development image vs production image

| Aspect | Development | Production |
|--------|-------------|------------|
| `devMode` | `true` (auto dev certs) | `false` (real PKI, enforced passwords) |
| Vault | H2 file | external PostgreSQL (`DB_TYPE=postgresql`) |
| Network | bootstrapper (offline) | doorman + network map, or bootstrapper for a private zone |
| Base image | tag (`:8-jre-jammy`) | **pinned by digest** (`@sha256:…`) |
| Secrets | env defaults | from Key Vault / Secrets Manager (Parts 2 & 6) |
| RPC port | published to host | cluster-internal only (NetworkPolicy) |
| JVM heap | `-Xmx512m` | sized to the node pool (e.g. `-Xmx2g`+) |
| Resources | unconstrained | CPU/memory requests+limits (Part 2) |

The image is the *same artifact*; the difference is entirely configuration.

## Local network (docker-compose)

```bash
make network-up        # build images → bootstrap → start notary + node1 + node2
make network-wait      # block until all three are healthy
make network-status    # docker compose ps
make network-logs      # tail logs
make network-down      # stop + wipe volumes
```

The one-shot `bootstrap` service generates the trust root, `network-parameters`
and every `NodeInfo` into per-node volumes before the nodes start — see
[Part 3](./part3-network.md) for the bootstrapping deep-dive.

## Image scanning (bonus)

Two layers of scanning, both wired into CI (`.github/workflows/docker-image.yml`):

* **Misconfiguration** `trivy config` on the Dockerfiles/compose (runs with no
  daemon, so it also runs locally / pre-commit).
* **Vulnerabilities**  `trivy image` on the built `node-image`
  (`CRITICAL`/`HIGH`, `--ignore-unfixed`), results uploaded as SARIF to GitHub
  code scanning.

Run locally:

```bash
trivy config --severity HIGH,CRITICAL .         # misconfig (no daemon)
trivy image --severity HIGH,CRITICAL corda-node:local   # vulns (needs the built image)
```
