# AcmeCorp Corda Platform

Production-grade platform engineering for running [Corda Open Source 4.14](https://docs.r3.com/en/platform/corda/4.14/open-source.html)
nodes on Kubernetes.

This repository takes AcmeCorp's CorDapp (built elsewhere as a `.jar` artifact) and provides everything needed to
containerize, deploy, bootstrap, and operate a Corda network — image build, Helm chart, network bootstrap, CorDapp
delivery, CI/CD, and cloud infrastructure.

> **Status:** built bottom-up, one engagement part at a time. See [Engagement parts](#engagement-parts) for what is
> done and where it lives. Every change is validated **locally** (lint/template/scan) and **in CI** before it lands.

---

## Engagement parts

| # | Deliverable | Location | Status |
|---|-------------|----------|--------|
| 1 | Docker image for a Corda node (+ local `docker-compose` network) | `docker/`, `docker-compose.yml` ([docs](docs/part1-docker.md)) | ✅ done |
| 2 | Helm chart for a Corda node | `charts/` | _planned_ |
| 3 | Bootstrap a 3-node network on Kubernetes | `deploy/` | _planned_ |
| 4 | CorDapp deployment strategy | `docker/node-image/`, `docs/` | _planned_ |
| 5 | CI/CD pipelines | `.github/workflows/` | _planned_ |
| 6 | Infrastructure as Code (Terraform / Azure) | `terraform/` | _planned_ |

## Repository layout

```
.
├── docker/                 # Part 1 — container images
│   ├── jar-image/          #   base image: certified JDK + corda.jar
│   └── node-image/         #   runtime image: entrypoint, config templating, CorDapps
├── docker-compose.yml      # Part 1 — minimal local network (Notary + 2 nodes)
├── charts/                 # Part 2 — Helm chart(s)
├── deploy/                 # Part 3 — network bootstrap (Helmfile / Argo CD / scripts)
├── terraform/              # Part 6 — cloud infrastructure (Azure)
├── .github/workflows/      # Part 5 — CI/CD pipelines
├── docs/                   # design notes, diagrams, runbooks
└── Makefile                # one entry point for local validation + common tasks
```

## Local validation philosophy

This environment may not have a Docker daemon or a Kubernetes cluster, so we separate two kinds of checks:

* **Static / local** — runs anywhere, fast, no daemon required. Linting, schema validation, template rendering,
  config-as-code scanning. Driven by `make lint`.
* **Runtime / CI** — actually builds images and spins up a [Kind](https://kind.sigs.k8s.io/) cluster. Runs in
  GitHub Actions where a Docker daemon is available.

Run everything you can locally before pushing:

```bash
make help      # list available targets
make lint      # run all static checks that apply to the current tree
```

## Toolchain

Local validation uses (pinned versions live in CI):
`hadolint`, `shellcheck`, `yq`, `helm`, `kubeconform`, `conftest`, `trivy`, `terraform`, `helm-docs`.

## Conventions

* Conventional Commits (`feat:`, `fix:`, `docs:`, `ci:`, `chore:` …).
* Trunk-based: work merges to `main`; `main` → staging, semver tags → production (see Part 5).
* Nothing secret is committed. Keystore passwords, DB creds and TLS material come from a secrets manager at runtime.

## License

See [`LICENSE`](./LICENSE).
