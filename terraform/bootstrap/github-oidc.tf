variable "github_repository" {
  type        = string
  default     = ""
  description = "OWNER/REPO. Vacío: solo crear bucket (útil en Learner Lab)."
  validation {
    condition     = var.github_repository == "" || can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "Usa OWNER/REPO o deja vacío."
  }
}
variable "github_oidc_provider_arn" {
  type        = string
  default     = ""
  description = "Si ya existe el proveedor GitHub en la cuenta, indica su ARN para reutilizarlo."
}
variable "project" {
  type    = string
  default = "solicitud"
}
data "aws_caller_identity" "current" {}
locals {
  environments = var.github_repository != "" ? toset(["DEV", "QA", "PROD"]) : toset([])
  provider_arn = var.github_oidc_provider_arn != "" ? var.github_oidc_provider_arn : try(aws_iam_openid_connect_provider.github[0].arn, "")
}
resource "aws_iam_openid_connect_provider" "github" {
  count          = var.github_repository != "" && var.github_oidc_provider_arn == "" ? 1 : 0
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}
resource "aws_iam_role" "deploy" {
  for_each = local.environments
  name     = "github-${var.project}-${lower(each.key)}"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect = "Allow", Principal = { Federated = local.provider_arn }, Action = "sts:AssumeRoleWithWebIdentity",
    Condition = { StringEquals = {
      "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com",
      "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:environment:${each.key}"
    } }
  }] })
}
resource "aws_iam_role_policy" "deploy" {
  for_each = local.environments
  role     = aws_iam_role.deploy[each.key].id
  # Terraform requiere capacidades de aprovisionamiento amplias. Nunca asignar este rol a ECS.
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = [
      "ec2:*", "ecs:*", "ecr:*", "elasticloadbalancing:*", "rds:*", "cognito-idp:*",
      "apigateway:*", "amplify:*", "logs:*", "cloudwatch:*", "secretsmanager:*", "ssm:*", "sts:GetCallerIdentity"
    ], Resource = "*" },
    { Effect = "Allow", Action = ["s3:ListBucket", "s3:GetBucketLocation"], Resource = aws_s3_bucket.state.arn },
    { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"], Resource = "${aws_s3_bucket.state.arn}/solicitud/${lower(each.key)}/*" },
    { Effect = "Allow", Action = [
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:UpdateAssumeRolePolicy", "iam:PutRolePolicy",
      "iam:GetRolePolicy", "iam:DeleteRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole", "iam:TagRole", "iam:UntagRole"
    ], Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project}-${lower(each.key)}-*" },
    { Effect = "Allow", Action = ["iam:PassRole"], Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project}-${lower(each.key)}-*", Condition = { StringEquals = { "iam:PassedToService" = "ecs-tasks.amazonaws.com" } } },
    { Effect = "Allow", Action = ["iam:CreateServiceLinkedRole"], Resource = "*", Condition = { StringEquals = { "iam:AWSServiceName" = ["ecs.amazonaws.com", "elasticloadbalancing.amazonaws.com", "rds.amazonaws.com", "cognito-idp.amazonaws.com", "amplify.amazonaws.com"] } } }
  ] })
}
output "github_roles" {
  value = { for env, role in aws_iam_role.deploy : env => role.arn }
}
