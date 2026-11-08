########################################
# GitHub Actions OIDC provider
########################################
data "tls_certificate" "github_oidc" {
  url = "https://token.actions.githubusercontent.com"
}

#data "aws_caller_identity" "current" {} # Pastikan ini ada

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_oidc.certificates[0].sha1_fingerprint]
}

########################################
# DeployRole — assumed by GitHub Actions via OIDC
# 
# BEFORE (vulnerable): Hanya memvalidasi `aud`. 
# Tidak ada `sub` condition. Siapa pun (repo apa pun) bisa assume role ini.
########################################

resource "aws_iam_role" "deploy" {
  name = "${var.name_prefix}-DeployRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${var.legit_branch}"
          }
          # SENGAJA DIHAPUS UNTUK DEMO VULNERABLE
          #StringLike = {
           # "token.actions.githubusercontent.com:sub" = [
            #  "repo:${var.github_org}/*",
             # "repo:${var.github_org}@*/*"
            #]
          #}
        }
      }
    ]
  })
}

# THE THIRD LINK: Permissions
resource "aws_iam_role_policy" "deploy_permissions" {
  name = "${var.name_prefix}-deploy-permissions"
  role = aws_iam_role.deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudFormationDeploy"
        Effect = "Allow"
        Action = [
          "cloudformation:CreateStack",
          "cloudformation:UpdateStack", # Tambahan agar aman jika pakai 'deploy'
          "cloudformation:DescribeStacks",
          "cloudformation:DescribeStackEvents",
          "cloudformation:DeleteStack",
          "s3:CreateBucket",
          "s3:PutBucketTagging",
          "s3:DeleteBucket"
        ]
        Resource = "*"
      },
      {
        Sid    = "IamForStackCapabilities"
        Effect = "Allow"
        Action = [
          #"iam:CreateRole",
          #"iam:AttachRolePolicy",
          "iam:PassRole",
          "iam:GetRole"
        ]
        Resource = "*"
      },
      {
        Sid      = "AssumeWhatGetsCreated"
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.name_prefix}-*"
      }
    ]
  })
}

output "deploy_role_arn" {
  value = aws_iam_role.deploy.arn
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}
