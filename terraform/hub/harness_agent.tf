################################################################################
# Harness GitOps Agent — Hub Cluster
################################################################################

resource "harness_platform_gitops_agent" "hub_agent" {
  identifier = var.harness_agent_identifier
  account_id = var.harness_account_id
  project_id = var.harness_project_id != "" ? var.harness_project_id : null
  org_id     = var.harness_org_id
  name       = var.harness_agent_name
  type       = "MANAGED_ARGO_PROVIDER"

  metadata {
    namespace         = var.harness_agent_namespace
    high_availability = false
  }
}

################################################################################
# Retrieve the agent deploy YAML from Harness API
################################################################################
data "harness_platform_gitops_agent_deploy_yaml" "hub_agent" {
  identifier = harness_platform_gitops_agent.hub_agent.identifier
  account_id = var.harness_account_id
  project_id = var.harness_project_id != "" ? var.harness_project_id : null
  org_id     = var.harness_org_id
  namespace  = var.harness_agent_namespace
}

################################################################################
# Create namespace and deploy agent to the EKS cluster
################################################################################
resource "kubernetes_namespace" "gitops_agent" {
  depends_on = [module.eks]

  metadata {
    name = var.harness_agent_namespace
  }
}

resource "local_file" "gitops_agent_yaml" {
  filename = "${path.module}/gitops_agent.yaml"
  content  = data.harness_platform_gitops_agent_deploy_yaml.hub_agent.yaml
}

resource "null_resource" "deploy_gitops_agent" {
  triggers = {
    yaml_content = sha256(local_file.gitops_agent_yaml.content)
  }

  provisioner "local-exec" {
    when    = create
    command = <<-EOT
      aws eks update-kubeconfig \
        --name ${module.eks.cluster_name} \
        --region ${local.region}
      kubectl apply -f ${local_file.gitops_agent_yaml.filename}
      echo "Waiting for agent pods to start..."
      kubectl -n ${var.harness_agent_namespace} wait --for=condition=ready pod --all --timeout=120s || true
    EOT
  }

  depends_on = [kubernetes_namespace.gitops_agent, local_file.gitops_agent_yaml]
}

resource "null_resource" "destroy_gitops_agent" {
  triggers = {
    filename = local_file.gitops_agent_yaml.filename
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete -f ${self.triggers.filename} --ignore-not-found=true"
  }

  depends_on = [local_file.gitops_agent_yaml]
}

################################################################################
# Fleet Repository — public (HTTPS anonymous, no credentials needed for test)
################################################################################
resource "harness_platform_gitops_repository" "fleet_repo" {
  identifier = var.gitops_fleet_repo_name
  account_id = var.harness_account_id
  project_id = var.harness_project_id != "" ? var.harness_project_id : null
  org_id     = var.harness_org_id
  agent_id   = harness_platform_gitops_agent.hub_agent.identifier

  repo {
    repo            = local.gitops_fleet_repo_url
    name            = var.gitops_fleet_repo_name
    insecure        = true
    connection_type = "HTTPS_ANONYMOUS"
  }

  upsert   = true
  gen_type = "UNSET"

  depends_on = [null_resource.deploy_gitops_agent]
}

################################################################################
# Register in-cluster as a GitOps cluster in Harness
################################################################################
resource "harness_platform_gitops_cluster" "hub_in_cluster" {
  identifier = local.cluster_name
  account_id = var.harness_account_id
  project_id = var.harness_project_id != "" ? var.harness_project_id : null
  org_id     = var.harness_org_id
  agent_id   = harness_platform_gitops_agent.hub_agent.identifier

  request {
    upsert = true
    cluster {
      server = "https://kubernetes.default.svc"
      name   = local.cluster_name
      config {
        tls_client_config {
          insecure = true
        }
        cluster_connection_type = "IN_CLUSTER"
      }
    }
  }

  depends_on = [null_resource.deploy_gitops_agent]
}

################################################################################
# ArgoCD cluster secret for in-cluster — carries labels and annotations
# that the ApplicationSet generators use for fleet membership and repo config
################################################################################
resource "kubernetes_secret" "in_cluster_metadata" {
  metadata {
    name      = "cluster-${local.cluster_name}"
    namespace = var.harness_agent_namespace
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
      "fleet_member"                   = var.fleet_member
      "tenant"                         = var.tenant
      "environment"                    = var.environment
    }
    annotations = {
      "fleet_repo_url"      = local.gitops_fleet_repo_url
      "fleet_repo_path"     = var.gitops_fleet_repo_path
      "fleet_repo_basepath" = var.gitops_fleet_repo_base_path
      "fleet_repo_revision" = var.gitops_fleet_repo_revision
    }
  }

  data = {
    name   = local.cluster_name
    server = "https://kubernetes.default.svc"
    config = jsonencode({
      tlsClientConfig = {
        insecure = true
      }
    })
  }

  depends_on = [
    kubernetes_namespace.gitops_agent,
    null_resource.deploy_gitops_agent
  ]
}

################################################################################
# Bootstrap ApplicationSet — deploys the fleet management ApplicationSets
# This mirrors harness-gitops-fleet/harness-bootstrap.yaml but is applied
# via Terraform so the cluster is fully bootstrapped on first deploy.
################################################################################
resource "kubectl_manifest" "bootstrap_applicationset" {
  yaml_body = templatefile("${path.module}/bootstrap/applicationsets.yaml", {})

  depends_on = [
    harness_platform_gitops_cluster.hub_in_cluster,
    harness_platform_gitops_repository.fleet_repo,
    null_resource.deploy_gitops_agent
  ]
}

################################################################################
# Hub cluster metadata secret (unchanged — used for spoke registration)
################################################################################
resource "aws_secretsmanager_secret" "hub_cluster_secret" {
  name                    = "hub/${local.cluster_name}"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "hub_cluster_secret_version" {
  secret_id = aws_secretsmanager_secret.hub_cluster_secret.id
  secret_string = jsonencode({
    cluster_name = module.eks.cluster_name
    metadata     = local.addons_metadata
    addons       = {}
    server       = module.eks.cluster_endpoint
    config = {
      tlsClientConfig = {
        insecure = false,
      },
    }
  })
}
