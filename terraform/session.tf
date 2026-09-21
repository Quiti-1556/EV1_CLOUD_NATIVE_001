resource "random_password" "cookie_key" {
  length  = 64
  special = false
}
resource "aws_secretsmanager_secret" "session" {
  name                    = "${local.name}/session-cookie-key"
  recovery_window_in_days = 7
}
resource "aws_secretsmanager_secret_version" "session" {
  secret_id     = aws_secretsmanager_secret.session.id
  secret_string = random_password.cookie_key.result
}
resource "aws_iam_role" "session" {
  count              = local.create_user_token_ms_role ? 1 : 0
  name               = "${local.name}-session"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}
resource "aws_iam_role_policy" "session" {
  count = local.create_user_token_ms_role ? 1 : 0
  role  = aws_iam_role.session[0].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = aws_secretsmanager_secret.session.arn },
    { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.session.arn}:*" }
  ] })
}
data "archive_file" "session" {
  type        = "zip"
  source_file = "${path.module}/../.runtime/session-ms/index.mjs"
  output_path = "${path.module}/session-ms.zip"
}
resource "aws_cloudwatch_log_group" "session" {
  name              = "/aws/lambda/${local.name}-session"
  retention_in_days = var.environment == "prod" ? 90 : 14
}
resource "aws_lambda_function" "session" {
  function_name    = "${local.name}-session"
  role             = local.create_user_token_ms_role ? aws_iam_role.session[0].arn : local.user_token_ms_role
  runtime          = "nodejs22.x"
  handler          = "index.handler"
  filename         = data.archive_file.session.output_path
  source_code_hash = data.archive_file.session.output_base64sha256
  timeout          = 20
  memory_size      = 256
  environment {
    variables = {
      PUBLIC_ORIGIN      = local.frontend_url
      COGNITO_DOMAIN     = local.cognito_domain
      COGNITO_CLIENT_ID  = aws_cognito_user_pool_client.web.id
      COOKIE_SECRET_ARN  = aws_secretsmanager_secret.session.arn
      SESSION_API_ORIGIN = aws_apigatewayv2_api.api.api_endpoint
    }
  }
  depends_on = [aws_iam_role_policy.session, aws_cloudwatch_log_group.session, aws_secretsmanager_secret_version.session]
}
resource "aws_lambda_permission" "gateway_session" {
  statement_id  = "AllowGatewaySession"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.session.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*/auth/*"
}
resource "aws_apigatewayv2_integration" "session" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.session.invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 25000
}
resource "aws_apigatewayv2_route" "session" {
  for_each           = toset(["GET /auth/login", "GET /auth/callback", "POST /auth/refresh", "POST /auth/logout"])
  api_id             = aws_apigatewayv2_api.api.id
  route_key          = each.key
  target             = "integrations/${aws_apigatewayv2_integration.session.id}"
  authorization_type = "NONE"
}
