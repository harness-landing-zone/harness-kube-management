
################################################################################
# External Secrets EKS Pod Identity for Extenal Secrets
# In this example we use external secrets For both Fleet namespace and Notmal External secret namespace
################################################################################
module "external_secrets_pod_identity" {
  # count   = local.aws_resources.enable_external_secrets_pod_identity ? 1 : 0
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "~> 1.12.0"

  name = "external-secrets"
  # Example of policy Statement to allow Extrnal Secret Operator of Spoke account to pull Secrets from HUB
  policy_statements = concat(
    var.external_secrets_cross_account_role != "" ? [
      {
        sid       = "crossaccount"
        actions   = ["sts:AssumeRole", "sts:TagSession"]
        resources = [var.external_secrets_cross_account_role]
      }
    ] : [],
  )

  additional_policy_arns = {
    AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  }

  # Give Permitions to External secret to Assume Remote From Hub Account
  external_secrets_kms_key_arns         = ["arn:aws:kms:${local.region}:${data.aws_caller_identity.current.account_id}:key/*"]
  external_secrets_secrets_manager_arns = ["arn:aws:secretsmanager:${local.region}:${data.aws_caller_identity.current.account_id}:secret:*"]
  external_secrets_ssm_parameter_arns   = ["arn:aws:ssm:${local.region}:${data.aws_caller_identity.current.account_id}:parameter/*"]
  attach_external_secrets_policy        = true
  external_secrets_create_permission    = false

  # Pod Identity Associations
  associations = {
    fleet = {
      cluster_name    = module.eks.cluster_name
      namespace       = "external-secrets"
      service_account = "external-secrets"
    }
  }

  tags = local.tags
}

################################################################################
# AWS ALB Ingress Controller EKS Access
################################################################################
# module "aws_lb_controller_pod_identity" {
#   count   = local.enable_automode || local.aws_resources.enable_aws_lb_controller_pod_identity ? 1 : 0
#   source  = "terraform-aws-modules/eks-pod-identity/aws"
#   version = "~> 1.12.0"

#   name = "aws-lbc"

#   attach_aws_lb_controller_policy = true


#   # Pod Identity Associations
#   associations = {
#     addon = {
#       cluster_name    = local.cluster_info.cluster_name
#       namespace       = local.aws_load_balancer_controller.namespace
#       service_account = local.aws_load_balancer_controller.service_account
#     }
#   }

#   tags = local.tags
# }
