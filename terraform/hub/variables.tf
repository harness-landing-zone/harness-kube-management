################################################################################
# Infrastructure Variables
################################################################################
variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "vpc_name" {
  description = "VPC name"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the hub VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway for all AZs (cost saving for non-prod)"
  type        = bool
  default     = true
}

################################################################################
# Cluster Related Variables
################################################################################
variable "eks_cluster_endpoint_public_access" {
  description = "Deploying public or private endpoint for the cluster"
  type        = bool
  default     = true
}

variable "managed_node_group_ami" {
  description = "The ami type of managed node group"
  type        = string
  default     = "BOTTLEROCKET_x86_64"
}

variable "managed_node_group_instance_types" {
  description = "List of managed node group instances"
  type        = list(string)
  default     = ["m5.xlarge"]
}

variable "ami_release_version" {
  description = "The AMI version of the Bottlerocket worker nodes"
  type        = string
  default     = ""
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
}

variable "tenant" {
  type        = string
  description = "Type of tenancy — control-plane for hub, tenant name for spoke"
}

variable "fleet_member" {
  description = "Fleet membership type of the cluster (hub or spoke)"
  type        = string
}

variable "cluster_name" {
  description = "Name of the cluster"
  type        = string
  default     = "gitops-hub-cluster"
}

variable "enable_automode" {
  description = "Enabling Automode Cluster"
  type        = bool
  default     = false
}

variable "aws_resources" {
  description = "Feature flags for AWS resource creation (pod identities, addons)"
  type        = any
  default     = {}
}

variable "environment" {
  description = "The environment of the Hub cluster"
  type        = string
}

################################################################################
# Git Repository Variables
################################################################################
variable "git_org_name" {
  description = "The name of the Github organisation"
  type        = string
  default     = ""
}

variable "gitops_fleet_repo_name" {
  description = "The fleet Git repository name"
  type        = string
  default     = ""
}

variable "gitops_fleet_repo_path" {
  description = "Path within the fleet repository"
  type        = string
  default     = ""
}

variable "gitops_fleet_repo_base_path" {
  description = "Base path within the fleet repository"
  type        = string
  default     = ""
}

variable "gitops_fleet_repo_revision" {
  description = "Git revision (branch/tag) for the fleet repository"
  type        = string
  default     = "main"
}

################################################################################
# Harness GitOps Variables
################################################################################
variable "harness_account_id" {
  description = "Harness account ID"
  type        = string
}

variable "harness_org_id" {
  description = "Harness organisation ID"
  type        = string
  default     = "default"
}

variable "harness_project_id" {
  description = "Harness project ID (leave empty for Org-level scope)"
  type        = string
  default     = ""
}

variable "harness_api_token" {
  description = "Harness platform API token (set via TF_VAR_harness_api_token env var)"
  type        = string
  sensitive   = true
}

variable "harness_endpoint" {
  description = "Harness API gateway endpoint"
  type        = string
  default     = "https://app.harness.io/gateway"
}

variable "harness_agent_identifier" {
  description = "Identifier for the Harness GitOps agent on the hub cluster"
  type        = string
  default     = "hub-agent"
}

variable "harness_agent_name" {
  description = "Display name for the Harness GitOps agent on the hub cluster"
  type        = string
  default     = "hub-agent"
}

variable "harness_agent_namespace" {
  description = "Kubernetes namespace for the Harness GitOps agent"
  type        = string
  default     = "harness-agent"
}

