################################################################################
# Harness GitOps — Spoke Cluster Registration
#
# Hub and spoke are in the same account. The spoke stores its cluster metadata
# in Secrets Manager so the hub's External Secrets Operator can discover it.
################################################################################

################################################################################
# IAM Role for Hub Agent to access spoke cluster via EKS access entries
################################################################################
data "aws_ssm_parameter" "harness_hub_role" {
  name = "/gitops-hub-cluster/agent-hub-role"
}

resource "aws_iam_role" "spoke" {
  name               = "${local.cluster_name}-harness-spoke"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_ssm_parameter.harness_hub_role.value]
    }
  }
}

################################################################################
# Spoke cluster metadata secret — deployed in the same (hub) account
# Hub's External Secrets Operator reads this to register the spoke cluster
################################################################################
resource "aws_secretsmanager_secret" "spoke_cluster_secret" {
  name                    = "${local.hub_cluster_name}/${local.cluster_name}"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "cluster_secret_version" {
  secret_id = aws_secretsmanager_secret.spoke_cluster_secret.id
  secret_string = jsonencode({
    cluster_name = module.eks.cluster_name
    metadata     = local.addons_metadata
    addons       = local.addons
    server       = module.eks.cluster_endpoint
    config = {
      tlsClientConfig = {
        insecure = false,
        caData   = module.eks.cluster_certificate_authority_data
      },
      awsAuthConfig = {
        clusterName = module.eks.cluster_name,
        roleARN     = aws_iam_role.spoke.arn
      }
    }
  })
}
