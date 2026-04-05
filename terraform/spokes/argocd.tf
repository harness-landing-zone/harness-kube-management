################################################################################
# Harness GitOps — Spoke Cluster Registration
#
# The hub Harness GitOps agent manages spoke clusters. The spoke registers
# itself as a GitOps cluster in Harness and stores its metadata in Secrets
# Manager so the hub can discover it.
################################################################################

################################################################################
# IAM Role for Hub Agent to access spoke cluster via EKS access entries
################################################################################
data "aws_ssm_parameter" "harness_hub_role" {
  provider = aws.shared-services
  name     = "/${local.hub_cluster_name}/harness-hub-role"
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
# External Secrets — Hub access to spoke secrets (unchanged)
################################################################################
data "aws_ssm_parameter" "external_secret_pod_identity_role" {
  provider = aws.shared-services
  name     = "/${local.hub_cluster_name}/external-secret-role"
}

################################################################################
# Spoke cluster metadata secret — local mode (secret in spoke account)
################################################################################
resource "aws_secretsmanager_secret" "spoke_cluster_secret" {
  count                   = var.remote_spoke_secret ? 0 : 1
  name                    = "${local.hub_cluster_name}/${local.cluster_name}"
  kms_key_id              = aws_kms_key.spoke_secret_kms[0].id
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "cluster_secret_version" {
  count     = var.remote_spoke_secret ? 0 : 1
  secret_id = aws_secretsmanager_secret.spoke_cluster_secret[0].id
  secret_string = jsonencode({
    cluster_name = local.cluster_info.cluster_name
    metadata     = local.addons_metadata
    addons       = local.addons
    server       = local.cluster_info.cluster_endpoint
    config = {
      tlsClientConfig = {
        insecure = false,
        caData   = local.cluster_info.cluster_certificate_authority_data
      },
      awsAuthConfig = {
        clusterName = local.cluster_info.cluster_name,
        roleARN     = aws_iam_role.spoke.arn
      }
    }
  })
}

resource "aws_secretsmanager_secret_policy" "secret_policy" {
  count      = var.remote_spoke_secret ? 0 : 1
  secret_arn = aws_secretsmanager_secret.spoke_cluster_secret[0].arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLocalAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "secretsmanager:*"
        Resource = "*"
      },
      {
        Sid    = "AllowTargetAccountAccess"
        Effect = "Allow"
        Principal = {
          AWS = data.aws_ssm_parameter.external_secret_pod_identity_role.value
        }
        Action   = "secretsmanager:GetSecretValue"
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_key" "spoke_secret_kms" {
  count                   = var.remote_spoke_secret ? 0 : 1
  description             = "KMS key for cross-account secret encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable Local Admin"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = data.aws_ssm_parameter.external_secret_pod_identity_role.value
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "spoke_secret_kms_alias" {
  count         = var.remote_spoke_secret ? 0 : 1
  name          = "alias/${local.hub_cluster_name}/${local.cluster_name}"
  target_key_id = aws_kms_key.spoke_secret_kms[0].key_id
}

################################################################################
# Spoke cluster metadata secret — remote mode (secret in hub account)
################################################################################
resource "aws_secretsmanager_secret" "remote_spoke_cluster_secret" {
  count                   = var.remote_spoke_secret ? 1 : 0
  provider                = aws.shared-services
  name                    = "${local.hub_cluster_name}/${local.cluster_name}"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "remote_cluster_secret_version" {
  count     = var.remote_spoke_secret ? 1 : 0
  provider  = aws.shared-services
  secret_id = aws_secretsmanager_secret.remote_spoke_cluster_secret[0].id
  secret_string = jsonencode({
    cluster_name = local.cluster_info.cluster_name
    metadata     = local.addons_metadata
    addons       = local.addons
    server       = local.cluster_info.cluster_endpoint
    config = {
      tlsClientConfig = {
        insecure = false,
        caData   = local.cluster_info.cluster_certificate_authority_data
      },
      awsAuthConfig = {
        clusterName = local.cluster_info.cluster_name,
        roleARN     = aws_iam_role.spoke.arn
      }
    }
  })
}
