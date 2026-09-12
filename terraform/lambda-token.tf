data "archive_file" "user_token_ms" {
  type        = "zip"
  source_file = "${path.module}/../user-token-ms/index.mjs"
  output_path = "${path.module}/user-token-ms.zip"
}

locals {
  user_token_ms_name = "${local.name}-user-token-ms"
  user_token_ms_role = var.existing_lambda_role_arn != "" ? var.existing_lambda_role_arn : (
    var.existing_task_role_arn != "" ? var.existing_task_role_arn : aws_iam_role.user_token_ms[0].arn
  )
  create_user_token_ms_role = var.existing_lambda_role_arn == "" && var.existing_task_role_arn == ""
}

resource "aws_iam_role" "user_token_ms" {
  count = local.create_user_token_ms_role ? 1 : 0

  name = "${local.name}-user-token-ms"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "user_token_ms" {
  count = local.create_user_token_ms_role ? 1 : 0

  role = aws_iam_role.user_token_ms[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "${aws_cloudwatch_log_group.user_token_ms.arn}:*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "user_token_ms" {
  name              = "/aws/lambda/${local.user_token_ms_name}"
  retention_in_days = var.environment == "prod" ? 90 : 14
}

resource "aws_lambda_function" "user_token_ms" {
  function_name = local.user_token_ms_name
  description   = "Pre Token Generation V2: convierte grupos Cognito en scopes del access token"
  role          = local.user_token_ms_role
  runtime       = "nodejs22.x"
  handler       = "index.handler"
  filename      = data.archive_file.user_token_ms.output_path

  source_code_hash = data.archive_file.user_token_ms.output_base64sha256
  timeout          = 5
  memory_size      = 128

  depends_on = [
    aws_cloudwatch_log_group.user_token_ms,
    aws_iam_role_policy.user_token_ms
  ]
}

resource "aws_lambda_permission" "cognito_user_token_ms" {
  statement_id  = "AllowCognitoPreTokenGeneration"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.user_token_ms.function_name
  principal     = "cognito-idp.amazonaws.com"
  # Evita un ciclo entre el permiso y la creación del User Pool.
  source_arn = "arn:aws:cognito-idp:${var.aws_region}:${data.aws_caller_identity.current.account_id}:userpool/*"
}
