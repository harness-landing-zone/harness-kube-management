################################################################################
# Spoke VPC
################################################################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k + 4)]

  enable_nat_gateway = true
  single_nat_gateway = var.single_nat_gateway

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Subnet tags required for EKS and load balancer discovery
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"             = 1
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }

  intra_subnet_tags = {
    "kubernetes.io/role/cni" = 1
    "karpenter.sh/discovery" = local.cluster_name
  }

  tags = local.tags
}
