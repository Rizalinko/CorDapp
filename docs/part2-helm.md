# Part 2 — Helm chart for a Corda node

Chart: [`charts/corda-node`](../charts/corda-node) · generated value reference:
[`charts/corda-node/README.md`](../charts/corda-node/README.md).

## One chart for Node and Notary — why not two?

**One chart.** In Corda OS a notary *is* a node — same JVM, same `corda.jar`,
same StatefulSet, Service, PVC, config and secret wiring. The only differences
are a `notary { validating = … }` block in `node.conf` and the legal name. Those
are two values (`role`, `notary.validating`), not a reason to fork the chart.

Two charts would duplicate ~95% of the templates and let them drift. We keep one
chart and select the role per release:

```bash
helm upgrade --install notary charts/corda-node -n corda -f deploy/notary/values.prd.yaml
helm upgrade --install node1  charts/corda-node -n corda -f deploy/node1/values.prd.yaml
helm upgrade --install node2  charts/corda-node -n corda -f deploy/node2/values.prd.yaml
```

If AcmeCorp later adopts a notary *cluster* (HA notary with its own replication),
that genuinely different topology would justify a dedicated `corda-notary-cluster`
chart — but a single OS notary does not.

## How `node.conf` is generated and what is parameterized

Two modes (`config.mode`):

* **`generate`** (default) — the entrypoint's `generate-config.sh` renders
  `node.conf` from environment variables on every start (`REGEN_CONFIG=true`), so
  a config change + rollout always takes effect. Non-secret values come from a
  **ConfigMap** (`*-env`); secret values are injected as env from a **Secret**.
  This is why secrets never appear in a ConfigMap.
* **`mounted`** — a complete `node.conf` from `config.existingConfigMap` is
  mounted verbatim (subPath) and used as-is. Use this for a bootstrapped network
  where the bootstrapper produced the config.

Parameterized values (full list in the chart README): `role`, `legalName`,
`devMode`, ports, `jvm.opts`, `db.*` (type/host/port/name/user/schema),
`notary.validating`, `network.compatibilityZoneUrl`, `rpc.user`. Secrets
(`rpc/db/keystore/truststore-password`) are referenced, never inlined.

The ConfigMap content is hashed into a pod annotation (`checksum/env`) so a
config edit rolls the StatefulSet automatically.

## How CorDapp JARs are loaded

`node.conf` sets `cordappDirectories` to **two** locations (from Part 1):

1. `/var/lib/corda/cordapps` — the mutable base dir on the PVC. Dev mounts jars
   here; an optional `cordapps.loader` initContainer can stage them from an OCI
   artifact / URL.
2. `/opt/corda/cordapps-baked` — baked into the image. This is the **production
   path**: the Part 4 *artifact image* layers the versioned CorDapp jars into the
   base node-image, so the running pod's CorDapp set is immutable and identical
   across every node (see [Part 4](./part4-cordapp.md)).

So by default the chart loads whatever CorDapps the image was built with;
`cordapps.loader.enabled=true` adds a side-channel for dev/extra jars.

## How certificates and keystores are managed

* **Production** — keystores (`nodekeystore.jks`, `sslkeystore.jks`,
  `truststore.jks`) and their passwords live in a Secret
  (`certificates.existingSecret` + the password Secret), ideally synced from
  Azure Key Vault (Part 6). An init container (`materialize-certs`) copies them
  onto the PVC's `certificates/` so Corda can read/write them. Keystore/truststore
  passwords are injected as `KEY_STORE_PASSWORD` / `TRUST_STORE_PASSWORD` env from
  the Secret — required when `devMode=false` (the chart fails fast otherwise).
* **Bootstrapped / dev** — the network bootstrapper writes dev certificates onto
  the PVC; no Secret needed and `devMode=true`.
* **`network-parameters` + `additional-node-infos`** come from
  `network.existingNetworkParams` (a ConfigMap produced by the Part 3 bootstrap
  job), staged onto the PVC by the `materialize-netparams` init container.

Nothing secret is ever committed or placed in a ConfigMap.

## Helm hooks used and why

| Hook | Resource | Why |
|------|----------|-----|
| `pre-install,pre-upgrade` (weight `-5`) | `*-migrate` Job | The PostgreSQL vault schema must exist (install) and be migrated (upgrade) **before** the node boots, or the node fails to start. The hook guarantees ordering. It runs with an `emptyDir` base dir (DB-only work) so it doesn't need — and can't contend for — the node's ReadWriteOnce PVC. `hook-delete-policy: before-hook-creation,hook-succeeded` keeps the namespace clean. |
| `test` | `*-test-rpc` Pod | `helm test` smoke-checks that the RPC port is reachable (node has fully started). |

## Security & operational defaults

* Non-root `podSecurityContext` (uid 1000, `fsGroup`, `seccompProfile:
  RuntimeDefault`); hardened container context (`allowPrivilegeEscalation:false`,
  drop `ALL` capabilities). `automountServiceAccountToken:false`.
* **NetworkPolicy**: P2P (10200) open to peers; RPC (10201/10202) restricted to
  `networkPolicy.rpcAllowedFrom` only — matching the brief (P2P allowed between
  nodes, RPC restricted).
* **PodDisruptionBudget** `minAvailable:1` so the singleton node survives drains.
* Probes tuned for Corda's slow first boot (`startupProbe`, default 600s budget).
* StatefulSet with `volumeClaimTemplate` for stable identity + storage.

## Validate locally

```bash
make lint-helm     # helm lint + template + kubeconform for every prod overlay
make docs-helm     # regenerate the chart README (helm-docs)
helm template node1 charts/corda-node -n corda -f deploy/node1/values.prd.yaml | less
```
