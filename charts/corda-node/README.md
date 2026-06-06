# corda-node

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 4.14](https://img.shields.io/badge/AppVersion-4.14-informational?style=flat-square)

Deploy a single Corda Open Source 4.x node — regular node OR notary — to Kubernetes. One parameterized chart covers both roles (a notary is a node with a notary{} block); pick the role in values.

**Homepage:** <https://github.com/acmecorp/corda-platform>

## Source Code

* <https://github.com/acmecorp/corda-platform>

## Requirements

Kubernetes: `>=1.27.0-0`

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| certificates | object | `{"existingSecret":""}` | ------------------------------------------------------------------------- |
| certificates.existingSecret | string | `""` | Name of a Secret mounted into /var/lib/corda/certificates (keystores + truststore). Empty = rely on PVC contents (bootstrapped/dev). |
| config | object | `{"existingConfigMap":"","mode":"generate"}` | ------------------------------------------------------------------------- |
| config.existingConfigMap | string | `""` | Name of a ConfigMap whose `node.conf` key is mounted verbatim (mode=mounted). |
| config.mode | string | `"generate"` | "generate": the entrypoint renders node.conf from env on every start (non-secret values here, secrets from `existingSecret`). "mounted": supply a complete node.conf via `existingConfigMap` (e.g. a bootstrapped network). |
| cordapps | object | `{"loader":{"command":[],"enabled":false,"image":""}}` | ------------------------------------------------------------------------- |
| cordapps.loader | object | `{"command":[],"enabled":false,"image":""}` | initContainer image + commands to stage CorDapp jars into cordapps/. Empty = use whatever the image baked into cordapps-baked/ (Part 4). |
| db | object | `{"host":"","name":"corda","port":5432,"schema":"corda","type":"h2","user":"corda"}` | ------------------------------------------------------------------------- |
| db.type | string | `"h2"` | "h2" or "postgresql". |
| devMode | bool | `false` | devMode disables PKI/password enforcement and uses Corda dev certs. MUST be false in production. |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.repository | string | `"ghcr.io/acmecorp/corda-node"` | node-image repository (built in Part 1). |
| image.tag | string | `""` | Image tag. Pin to an immutable semver+sha tag in production. |
| imagePullSecrets | list | `[]` | imagePullSecrets for private registries. |
| jvm.opts | string | `"-Xmx1500m -XX:+UseG1GC -XX:+ExitOnOutOfMemoryError"` | Passed verbatim as JAVA_OPTS. Keep -Xmx within the pod memory limit. |
| legalName | string | `""` | X.500 legal name for this node, e.g. "O=Node1, L=London, C=GB". Required. |
| migrations.enabled | bool | `true` |  |
| network | object | `{"compatibilityZoneUrl":"","existingNetworkParams":""}` | ------------------------------------------------------------------------- |
| network.compatibilityZoneUrl | string | `""` | Compatibility-zone URL (doorman + network map). Leave empty for a bootstrapped network (network-parameters supplied via `networkParameters`). |
| network.existingNetworkParams | string | `""` | ConfigMap/Secret carrying `network-parameters` + `additional-node-infos` for a bootstrapped network (set by the Part 3 bootstrap job). |
| networkPolicy.enabled | bool | `true` |  |
| networkPolicy.rpcAllowedFrom | list | `[]` | Extra namespace/pod selectors allowed to reach the RPC port. |
| nodeSelector | object | `{}` |  |
| notary | object | `{"validating":false}` | ------------------------------------------------------------------------- |
| notary.validating | bool | `false` | Validating vs non-validating notary. |
| persistence | object | `{"accessModes":["ReadWriteOnce"],"enabled":true,"existingClaim":"","size":"10Gi","storageClass":""}` | ------------------------------------------------------------------------- |
| persistence.existingClaim | string | `""` | Mount an existing PVC instead of a volumeClaimTemplate. |
| podAnnotations | object | `{}` |  |
| podDisruptionBudget.enabled | bool | `true` |  |
| podLabels | object | `{}` |  |
| podSecurityContext.fsGroup | int | `1000` |  |
| podSecurityContext.runAsGroup | int | `1000` |  |
| podSecurityContext.runAsNonRoot | bool | `true` |  |
| podSecurityContext.runAsUser | int | `1000` |  |
| podSecurityContext.seccompProfile.type | string | `"RuntimeDefault"` |  |
| ports.p2p | int | `10200` |  |
| ports.rpc | int | `10201` |  |
| ports.rpcAdmin | int | `10202` |  |
| priorityClassName | string | `""` |  |
| probes.startupSeconds | int | `600` |  |
| resources | object | `{"limits":{"memory":"2Gi"},"requests":{"cpu":"500m","memory":"2Gi"}}` | ------------------------------------------------------------------------- |
| role | string | `"node"` | Corda role: "node" (regular participant) or "notary". |
| rpc.user | string | `"corda"` |  |
| secrets | object | `{"create":false,"data":{"db-password":"","keystore-password":"","rpc-password":"","truststore-password":""},"existingSecret":""}` | ------------------------------------------------------------------------- |
| secrets.data | object | `{"db-password":"","keystore-password":"","rpc-password":"","truststore-password":""}` | Inline values for trials only (base64 NOT required; values are templated into a Secret). Do not commit real secrets here. |
| securityContext.allowPrivilegeEscalation | bool | `false` |  |
| securityContext.capabilities.drop[0] | string | `"ALL"` |  |
| securityContext.readOnlyRootFilesystem | bool | `false` |  |
| service.annotations | object | `{}` |  |
| service.p2pType | string | `"ClusterIP"` | P2P service type. ClusterIP for in-cluster; LoadBalancer to expose P2P to external counterparties. |
| serviceAccount.annotations | object | `{}` |  |
| serviceAccount.create | bool | `true` |  |
| serviceAccount.name | string | `""` |  |
| tolerations | list | `[]` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
