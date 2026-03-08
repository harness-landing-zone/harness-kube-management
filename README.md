# Harness GitOps Hub/Spoke Bootstrap

This repository manages a GitOps fleet using ArgoCD on a hub cluster to bootstrap Harness GitOps agents onto spoke clusters. Two deployment models are implemented.

---

## Repository Structure

```
harness-kube-management/
  charts/
    harness-gitops-agent-bootstrap/   # Helm chart: CR + gitops-helm runtime wrapper
    harness-gitops-agent-controller/  # Helm chart: Go operator (registers agents in Harness API)
    application-sets/                 # Generic ApplicationSet factory chart
  fleet-bootstrap/
    hub-managed/                      # Model 2 values files (one per spoke)
      spoke-2-agent.yaml
  gitops-apps/
    Team1/                            # Model 1 app manifests (deployed to spoke)
      applicationset.yaml
    Team2/                            # Model 2 app manifests (deployed to spoke-2 via hub ArgoCD)
      applicationset.yaml
      test-app/
  harness-bootstrap.yaml              # Root ApplicationSet — applied manually on hub
  harness-hub-agents.yaml             # Model 2 ApplicationSet — applied manually on hub
```

---

## Clusters Example

| Cluster | Context | Internal IP | Role |
|---|---|---|---|
| hub | Control plane, runs all ApplicationSets |
| spoke-1 | Model 1 target |
| spoke-2 | Model 2 target |

---

## Model 1 — Agent and Workloads on Spoke

### Overview

The hub deploys both the Harness GitOps agent controller and the agent runtime directly onto the spoke cluster. The spoke runs its own ArgoCD instance and manages its own workloads independently.

```
Hub ApplicationSets (gitops-agent ns)
  ├── harness-agent-controller-default  →  deploys operator chart to spoke
  └── harness-agent-bootstrap-default   →  deploys CR + gitops-helm to spoke

Spoke (gitops-agent ns)
  ├── HarnessGitopsAgent CR             →  controller registers agent in Harness API
  ├── Secret: my-agent-token            →  written by controller (GITOPS_AGENT_TOKEN)
  ├── ArgoCD instance                   →  connects to Harness as the spoke agent
  └── gitops-agent pod                  →  reads token from local secret
```

### How it works

1. Applicationset `harness-bootstrap.yaml` to hub. This root ApplicationSet targets clusters labelled `fleet_member: hub-cluster` and deploys `charts/application-sets` which generates two ApplicationSets.
2. `harness-agent-controller-default` deploys the Go operator to clusters with `enable_controller: "true"`.
3. `harness-agent-bootstrap-default`  deploys the bootstrap chart (CR + gitops-helm) to clusters with `enable_agent: "true"`.
4. The operator reconciles the `HarnessGitopsAgent` CR on the spoke:
   - Calls the Harness API to register the agent → gets `GITOPS_AGENT_TOKEN`
   - Writes the token to a local secret (`my-agent-token`) on the spoke
5. The gitops-agent pod on the spoke reads the token from `my-agent-token` and connects to Harness.

### Spoke cluster secret labels required

```yaml
labels:
  argocd.argoproj.io/secret-type: cluster
  enable_controller: "true"
  enable_agent: "true"
  fleet_member: spoke
```

---

## Model 2 — Hub-Managed Agent, Workloads on Spoke

### Overview

The hub controller registers the agent in Harness and runs the ArgoCD runtime in a dedicated namespace on the hub (`gitops-agent-<clusterName>`). The spoke-2 cluster is registered as a destination cluster inside that ArgoCD instance. Workloads are deployed to spoke-2, but the control plane and all secrets stay on the hub.

```
Hub (gitops-agent ns)
  └── harness-hub-agents ApplicationSet
        └── agent-spoke-2 Application
              └── deploys to gitops-agent-spoke-2 ns on hub:
                    ├── HarnessGitopsAgent CR    →  controller registers agent in Harness
                    ├── Secret: spoke-2-agent-token  →  written by controller
                    ├── ArgoCD instance          →  isolated instance for spoke-2
                    └── gitops-agent pod         →  connects to Harness as spoke2 agent

Hub (gitops-agent-spoke-2 ns) — ArgoCD instance
  └── team2-apps ApplicationSet
        └── team2-test-app Application  →  deploys to spoke-2 cluster
```

### How it works

1. Applicationset `harness-hub-agents.yaml` to hub. This ApplicationSet targets clusters labelled `fleet_member: hub-cluster` and reads values files from `fleet-bootstrap/hub-managed/*.yaml`.
2. For each values file, one Application is generated that deploys `charts/harness-gitops-agent-bootstrap` into a dedicated namespace `gitops-agent-<clusterName>` on the hub.
3. The bootstrap chart creates:
   - A `HarnessGitopsAgent` CR in that namespace
   - A full ArgoCD stack (gitops-helm subchart) in that namespace
4. The controller (running in `harness-system` on hub) reconciles the CR:
   - Registers the agent in Harness API
   - Writes `spoke-2-agent-token` secret into `gitops-agent-spoke-2`
5. The gitops-agent pod in `gitops-agent-spoke-2` reads the token locally and connects to Harness.
6. The spoke-2 cluster secret is added to `gitops-agent-spoke-2` namespace so the ArgoCD instance can deploy workloads to spoke-2.

### Values file per spoke (`fleet-bootstrap/hub-managed/<clusterName>-agent.yaml`)

```yaml
clusterName: spoke-2

harnessAgent:
  enabled: true
  spec:
    name: "spoke-2-hga"
    operator: "ARGO"
    scope: "PROJECT"
    type: "MANAGED_ARGO_PROVIDER"
    projectId: "argospoke2"
    apiKeySecretRef: "harness-api-key-secret"
    tokenSecretRef: "spoke-2-agent-token"

gitopsAgent:
  argo-cd:
    crds:
      install: false        # CRDs already installed by hub ArgoCD
    configs:
      cm:
        cluster.inClusterEnabled: "false"  # Only show spoke-2 in Harness UI, not hub
  harness:
    argocdHarnessPlugin:
      enabled: false        # Plugin not needed for plain YAML workloads
```

### Manual prerequisites per spoke namespace

These must exist in `gitops-agent-<clusterName>` before the agent can register:

| Resource | Type | Notes |
|---|---|---|
| `harness-api-key-secret` | Secret | Harness PAT with `api_key` key. Best practice: implement `apiKeySecretNamespace` in controller to read from central `gitops-agent` ns instead. |
| `cluster-spoke-2` | Secret (ArgoCD cluster) | Spoke cluster credentials with label `argocd.argoproj.io/secret-type: cluster` |

### Developer workflow (Team2)

Developers push application manifests to `gitops-apps/Team2/<app-name>/`. The `team2-apps` ApplicationSet (running inside the `gitops-agent-spoke-2` ArgoCD instance) watches that path and deploys each subdirectory to the spoke-2 cluster.

```
Developer pushes to gitops-apps/Team2/my-app/
  → team2-apps ApplicationSet (gitops-agent-spoke-2 ArgoCD on hub) generates Application
    → workload deployed on spoke-2 cluster
```

Harness sees spoke-2 as the registered cluster under the `spoke2` agent. Deployments are visible and manageable from the Harness GitOps UI.

---

## Model Comparison

| | Model 1 | Model 2 |
|---|---|---|
| Agent runtime location | Spoke | Hub (isolated namespace) |
| Secrets location | Spoke | Hub only |
| Spoke access required | Full (controller + agent) | Destination cluster only |
| CRD install on spoke | Yes | No (reuses hub CRDs) |
| In-cluster shown in Harness | Yes (spoke's own) | No (disabled) |
| Best for | Full autonomy per spoke | Centralised control, secrets never leave hub |

---

## Known Issues & Gotchas

- **`apiKeySecretRef` is namespace-scoped**: The controller reads the Harness API key secret from the same namespace as the CR. For Model 2 this means manually creating `harness-api-key-secret` in each `gitops-agent-<clusterName>` namespace. Future improvement: add `apiKeySecretNamespace` field to the CRD so it can reference the central `gitops-agent` namespace.
- **ArgoCD CRD conflict**: Running a second ArgoCD instance on the hub requires `crds.install: false` in the gitops-helm values to avoid conflicts with the existing CRDs.
- **Harness plugin sidecar**: The gitops-helm chart includes an `argocd-harness-plugin` sidecar on the repo-server. Set `argocdHarnessPlugin.enabled: false` for Model 2 instances that only serve plain YAML or Helm workloads.
- **k3d networking**: ArgoCD cluster secrets must use the spoke container's direct Docker IP (e.g. `192.168.147.2:6443`), not the host-mapped port or `host.k3d.internal` hostname, as CoreDNS in hub pods cannot resolve k3d hostnames.

---

## Roadmap / TODO

### External Secrets Operator (ESO)

Currently secrets such as `harness-api-key-secret` and ArgoCD cluster registration secrets are created manually or outside of GitOps. The goal is to integrate [External Secrets Operator](https://external-secrets.io) so that all secrets are sourced from a central secrets manager (e.g. HashiCorp Vault, AWS Secrets Manager, or GCP Secret Manager) and synced automatically into the correct namespaces.

Planned work:
- Deploy ESO onto the hub cluster as part of the bootstrap chart
- Define `ExternalSecret` resources that pull:
  - `harness-api-key-secret` into every `gitops-agent-<clusterName>` namespace (replaces manual copy)
  - ArgoCD cluster registration secrets (CA, cert, key) for each spoke
- For Model 2: a single `ClusterSecretStore` on hub can serve all `gitops-agent-*` namespaces, so the Harness API key is stored once and synced everywhere automatically
- Removes the last manual step from the bootstrap flow

### ApplicationSet Controller (AppSet Manager)

Currently `team2-apps` ApplicationSet is applied manually to the `gitops-agent-spoke-2` namespace. The goal is to have a dedicated ApplicationSet controller layer that manages ApplicationSets themselves as a GitOps resource — so teams can self-service their own ApplicationSets without hub admin intervention.

Planned work:
- Add an `appset-manager` Application (or ApplicationSet) deployed by the hub bootstrap that watches `gitops-apps/<TeamN>/applicationset.yaml` in the repo
- Automatically deploys each team's ApplicationSet into the correct ArgoCD instance namespace on the hub
- Teams commit their `applicationset.yaml` to their folder and it is picked up and applied without any manual `kubectl apply`
- Supports both Model 1 (spoke ArgoCD) and Model 2 (hub-namespaced ArgoCD) by routing to the correct namespace based on folder structure
