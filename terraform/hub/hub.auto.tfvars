################################################################################
# VPC
################################################################################
vpc_name           = "gitops-hub-cluster"
vpc_cidr           = "10.0.0.0/16"
single_nat_gateway = true

################################################################################
# EKS Cluster
################################################################################
kubernetes_version = "1.34"
cluster_name       = "gitops-hub-cluster"
environment        = "dev"
fleet_member       = "hub-cluster"
tenant             = "control-plane"

################################################################################
# AWS Resources (pod identities / addons)
################################################################################
aws_resources = {
  enable_aws_cloudwatch_observability = true
  enable_cni_metrics_helper           = true
  enable_external_secrets             = true
}

################################################################################
# Git Repositories
################################################################################
git_org_name                = "harness-landing-zone"
gitops_fleet_repo_name      = "harness-kube-management"
gitops_fleet_repo_base_path = ""
gitops_fleet_repo_path      = "bootstrap"
gitops_fleet_repo_revision  = "eks"

################################################################################
# Harness GitOps
################################################################################
harness_account_id       = "qIYsos1ZQO6fJMG1Ip6KJA"
harness_org_id           = "eksfleetmanagement"
harness_agent_identifier = "hub-agent"
harness_agent_name       = "hub-agent"
harness_agent_namespace  = "harness-agent"
# harness_api_token — set via: export TF_VAR_harness_api_token="<your-pat>"
