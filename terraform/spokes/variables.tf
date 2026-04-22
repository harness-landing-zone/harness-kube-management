variable "spoke_cluster_name" {
  description = "Name of the spoke cluster"
  type        = string
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

variable "hub_cluster_name" {
  description = "Name of the hub cluster for secret registration"
  type        = string
  default     = "hub-cluster"
}

variable "tenant" {
  description = "Name of the tenant where the cluster belongs to"
  type        = string
}

variable "deployment_environment" {
  description = "The environment that this cluster will be deployed (np, prelife, prod)"
  type        = string
  default     = ""
}

variable "kubernetes_version" {
  description = "The version of the Kubernetes cluster"
  type        = string
}

variable "enable_automode" {
  description = "Enabling Automode Cluster"
  type        = bool
  default     = false
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

variable "eks_cluster_endpoint_public_access" {
  description = "Deploying public or private endpoint for the cluster"
  type        = bool
  default     = true
}

variable "external_secrets_cross_account_role" {
  default = ""
}