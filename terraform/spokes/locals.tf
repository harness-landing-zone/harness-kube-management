locals {
  hub_cluster_name = var.hub_cluster_name
  enable_automode  = var.enable_automode
  cluster_name     = var.spoke_cluster_name
  cluster_version  = var.kubernetes_version
  region           = data.aws_region.current.id
  azs              = slice(data.aws_availability_zones.available.names, 0, 3)
  fleet_member     = "spoke"

  addons = merge(
    { fleet_member = local.fleet_member },
    { kubernetes_version = local.cluster_version },
    { aws_cluster_name = module.eks.cluster_name },
    { aws_region = local.region }
  )

  addons_metadata = merge(
    {
      aws_cluster_name = module.eks.cluster_name
      aws_region       = local.region
      aws_account_id   = data.aws_caller_identity.current.account_id
    }
  )

  cluster_admin_role_arns = [aws_iam_role.spoke.arn, tolist(data.aws_iam_roles.eks_admin_role.arns)[0]]

  admin_access_entries = {
    for role_arn in local.cluster_admin_role_arns : role_arn => {
      principal_arn = role_arn
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

  access_entries = merge({}, local.admin_access_entries)

  tags = {
    Blueprint = local.cluster_name
  }
}
