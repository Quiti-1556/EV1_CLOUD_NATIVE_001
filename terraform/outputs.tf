output "deployment" {
  value = {
    DB_APP_SECRET_ARN                = aws_secretsmanager_secret.app.arn
    ECS_MIGRATION_TEMPLATE_PARAMETER = aws_ssm_parameter.migration_template.name
    ECS_SUBNETS                      = join(",", aws_subnet.app[*].id)
    ECS_SECURITY_GROUP               = aws_security_group.app.id
    AWS_REGION                       = var.aws_region
    ECR_REPO                         = aws_ecr_repository.backend.repository_url
    ECS_CLUSTER                      = aws_ecs_cluster.backend.name
    ECS_SERVICE                      = aws_ecs_service.backend.name
    ECS_TASK_TEMPLATE_PARAMETER      = aws_ssm_parameter.task_template.name
    ECS_DESIRED_COUNT                = tostring(var.task_count)
    AMPLIFY_APP_ID                   = aws_amplify_app.front.id
    AMPLIFY_BRANCH                   = aws_amplify_branch.main.branch_name
    FRONTEND_API_URL                 = aws_apigatewayv2_api.api.api_endpoint
    SESSION_API_URL                  = aws_apigatewayv2_api.api.api_endpoint
    SESSION_LAMBDA_NAME              = aws_lambda_function.session.function_name
    API_URL                          = aws_apigatewayv2_api.api.api_endpoint
    COGNITO_DOMAIN                   = local.cognito_domain
    COGNITO_CLIENT_ID                = aws_cognito_user_pool_client.web.id
    COGNITO_ISSUER_URI               = local.issuer
    COGNITO_USER_POOL_ID             = aws_cognito_user_pool.users.id
    TOKEN_LAMBDA_NAME                = aws_lambda_function.user_token_ms.function_name
    TOKEN_LAMBDA_LOG_GROUP           = aws_cloudwatch_log_group.user_token_ms.name
    REDIRECT_URI                     = "${local.frontend_url}/"
  }
}
output "frontend_url" {
  value = local.frontend_url
}
output "api_url" {
  value = aws_apigatewayv2_api.api.api_endpoint
}
output "db_secret_arn" {
  value = aws_db_instance.db.master_user_secret[0].secret_arn
}
output "logs" {
  value = aws_cloudwatch_log_group.backend.name
}
