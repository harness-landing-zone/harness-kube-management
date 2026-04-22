################################################################################
# EKS Cluster
################################################################################
#tfsec:ignore:aws-eks-enable-control-plane-logging
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.17"

  name                   = local.cluster_name
  kubernetes_version     = local.cluster_version
  endpoint_public_access = var.eks_cluster_endpoint_public_access

  # Disable control plane logs to save ~$60/mo
  enabled_log_types           = []
  create_cloudwatch_log_group = false

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # Cluster access entry
  enable_cluster_creator_admin_permissions = false

  access_entries = {
    kube-admins = {
      principal_arn = tolist(data.aws_iam_roles.eks_admin_role.arns)[0]
      policy_associations = {
        admins = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
    harness-hub = {
      principal_arn = aws_iam_role.spoke.arn
      policy_associations = {
        admins = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  eks_managed_node_groups = local.enable_automode ? {} : {
    platform = {
      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore    = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
        AmazonSSMDirectoryServiceAccess = "arn:aws:iam::aws:policy/AmazonSSMDirectoryServiceAccess"
        CloudWatchAgentServerPolicy     = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
      }
      instance_types                 = var.managed_node_group_instance_types
      ami_type                       = var.managed_node_group_ami
      ami_release_version            = var.ami_release_version
      use_latest_ami_release_version = var.managed_node_group_ami != "" ? false : true
      min_size                       = 3
      max_size                       = 6
      desired_size                   = 3
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 10
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 125
            encrypted             = true
            delete_on_termination = true
          }
        }
        xvdb = {
          device_name = "/dev/xvdb"
          ebs = {
            volume_size           = 25
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 125
            encrypted             = true
            delete_on_termination = true
          }
        }
      }
    }
  }

  compute_config = local.cluster_compute_config

  # EKS Addons
  addons = local.enable_automode ? {} : {
    amazon-cloudwatch-observability = {
      most_recent = true
    }
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
    vpc-cni = {
      before_compute = true
      most_recent    = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
  }

  security_group_additional_rules = {
    cluster_internal_ingress = {
      description = "Access EKS from VPC."
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      cidr_blocks = [module.vpc.vpc_cidr_block]
    }
  }

  node_security_group_additional_rules = {
    vpc_cni_metrics_traffic = {
      description                   = "Cluster API to node 61678/tcp vpc cni metrics"
      protocol                      = "tcp"
      from_port                     = 61678
      to_port                       = 61678
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  node_security_group_tags = {
    "karpenter.sh/discovery" = local.cluster_name
  }

  tags = local.tags
}

locals {
  _cluster_compute_configs = {
    true = {
      enabled    = true
      node_pools = ["general-purpose", "system"]
    }
    false = {}
  }

  cluster_compute_config = local._cluster_compute_configs[tostring(local.enable_automode)]
}
