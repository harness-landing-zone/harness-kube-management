clusterName: spoke-2
harnessAgent:
  enabled: true
  metadata:
    name: "spoke2-agent"
  spec:
    name: "spoke2-agent"
    operator: "ARGO"
    scope: "PROJECT"
    type: "MANAGED_ARGO_PROVIDER"
    projectId: "Spoke2"
    apiKeySecretRef: "harness-api-key-secret"
    tokenSecretRef: "spoke-2-agent-token"
    projectMapping:
      projectId: "Spoke2"
      AppProject: "default"
gitopsAgent:
  enabled: true
  argo-cd:
    crds:
      install: false
      keep: true
    configs:
      cm:
        cluster.inClusterEnabled: "false"
  harness:
    identity:
      accountIdentifier: "qIYsos1ZQO6fJMG1Ip6KJA"
      orgIdentifier: "gitops_fleet_management"
      projectIdentifier: "Spoke2"
      agentIdentifier: "spoke_2"
    configMap:
      http:
        tlsEnabled: false
        agentHttpTarget: "https://app.harness.io/gitops"
      logLevel: "info"
    argocdHarnessPlugin:
      enabled: false
  agent:
    existingSecrets:
      agentToken: "spoke-2-agent-token"
