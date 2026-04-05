variable "kms_key_admin_roles" {
  description = "list of role ARNs to add to the KMS policy"
  type        = list(string)
  default     = []

}

variable "hub_account_id" {
  description = "We are using this to allow permissions on the hub account to read the secret and KMS key for cross account hub and spoke"
  default     = ""
}

variable "route53_zone_name" {
  description = "the Name of Route53 zone for external dns"
  type        = string
  default     = ""
}

variable "vpc_name" {
  description = "The prefix name of the vpc for the data to look for it"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the spoke VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway for all AZs (cost saving for non-prod)"
  type        = bool
  default     = true
}

variable "accounts_config" {
  description = "Map of objects for per environment configuration"
  type = map(object({
    account_id = string
  }))
}

################################################################################
# Cluster Realted Variables
################################################################################
variable "external_secrets_cross_account_role" {
  description = "The role that is on app tooling and hib to allow spoke clusters to get secret infromations from the accounts"
  default     = ""
}

variable "tenant" {
  description = "Name of the tenant where the cluster belongs to"
  type        = string
}

variable "cluster_type" {
  description = "The type of cluster if it belong to tenant or to platorfom team"
  type        = string
}

variable "hub_cluster_name" {
  description = "Enabling Automode Cluster"
  type        = string
  default     = "hub-cluster"
}

variable "deployment_environment" {
  description = "The environment that this cluster will be deployd this can be np,prelife,prod"
  default     = ""
  type        = string
}

variable "kubernetes_version" {
  type        = string
  description = "The version of the Kubernetes cluster"
}

variable "aws_resources" {
  description = "Enabling or desabling pod identity via terraform"
  type        = any
  default     = {}
}

variable "enable_automode" {
  description = "Enabling Automode Cluster"
  type        = bool
  default     = false
}

variable "enable_ack_pod_identity" {
  description = "Defining to use ack or terraform for pod identity if this is true then we will use this label to deploy resouces with ack"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "The domain name that will be used for argo ingress"
  type        = string
  default     = ""
}

variable "remote_spoke_secret" {
  description = "If this is true then the secret is deploed on the Hub account if this is false its allowing"
  type        = bool
  default     = false
}

variable "amp_prometheus_crossaccount_role" {
  description = "Adot Role in the App tooling account that will allow to connect with prometheus"
  type        = string
  default     = ""
}

variable "environment_prefix" {
  description = "Prefix for different workspace envrironments"
  default     = ""
  type        = string
}

variable "managed_node_group_ami" {
  description = "The ami type of managed node group"
  type        = string
  default     = "BOTTLEROCKET_x86_64"
}

variable "managed_node_group_instance_types" {
  description = "List of managed node group instances"
  type        = list(string)
  default     = ["m5.large"]
}

variable "ami_release_version" {
  description = "The AMI version of the Bottlerocket worker nodes"
  type        = string
  default     = ""
}

variable "eks_cluster_endpoint_public_access" {
  description = "Deploying public or private endpoint for the cluster"
  type    = bool
  default = true
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
  description = "Harness project ID"
  type        = string
  default     = "default_project"
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
  description = "Identifier for the Harness GitOps agent on this spoke cluster"
  type        = string
  default     = ""
}

variable "harness_agent_name" {
  description = "Display name for the Harness GitOps agent on this spoke cluster"
  type        = string
  default     = ""
}

variable "harness_agent_namespace" {
  description = "Kubernetes namespace for the Harness GitOps agent"
  type        = string
  default     = "gitops-agent"
}