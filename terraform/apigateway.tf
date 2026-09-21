resource "aws_apigatewayv2_api" "api" {
  name          = local.name
  protocol_type = "HTTP"
  # Solo el frontend conocido; nunca "*" con cookies.
  cors_configuration {
    allow_origins     = local.origins
    allow_credentials = true
    allow_methods     = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers     = ["Authorization", "Content-Type", "X-CSRF"]
    expose_headers    = ["X-Gateway-Request-Id"]
    max_age           = 300
  }
}
resource "aws_apigatewayv2_vpc_link" "backend" {
  name               = local.name
  subnet_ids         = aws_subnet.app[*].id
  security_group_ids = [aws_security_group.link.id]
}
resource "aws_apigatewayv2_integration" "backend" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  integration_uri        = aws_lb_listener.backend.arn
  connection_type        = "VPC_LINK"
  connection_id          = aws_apigatewayv2_vpc_link.backend.id
  payload_format_version = "1.0"
  timeout_milliseconds   = 29000
  request_parameters = {
    "overwrite:path"                        = "$request.path"
    "overwrite:header.X-Verified-User"      = "$context.authorizer.claims.sub"
    "overwrite:header.X-Verified-Name"      = "$context.authorizer.claims.verified_name"
    "overwrite:header.X-Verified-Scopes"    = "$context.authorizer.claims.scope"
    "overwrite:header.X-Gateway-Request-Id" = "$context.requestId"
  }
}
resource "aws_apigatewayv2_authorizer" "jwt" {
  api_id           = aws_apigatewayv2_api.api.id
  name             = "cognito"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  jwt_configuration {
    audience = [aws_cognito_user_pool_client.web.id]
    issuer   = local.issuer
  }
}
locals {
  solicitud_routes = {
    "GET /datos"                      = ["solicitudes/read"]
    "GET /solicitudes"                = ["solicitudes/read"]
    "GET /solicitudes/mias"           = ["solicitudes/read"]
    "GET /solicitudes/pendientes"     = ["solicitudes/approve"]
    "GET /solicitudes/{id}"           = ["solicitudes/read"]
    "POST /solicitudes"               = ["solicitudes/write"]
    "PUT /solicitudes/{id}"           = ["solicitudes/write"]
    "DELETE /solicitudes/{id}"        = ["solicitudes/write"]
    "POST /solicitudes/{id}/decision" = ["solicitudes/approve"]
  }
  api_routes = merge(local.solicitud_routes, {
    for route, scopes in local.solicitud_routes : replace(route, "/solicitudes", "/productos") => scopes
    if strcontains(route, "/solicitudes")
  })
}
resource "aws_apigatewayv2_route" "api" {
  for_each             = local.api_routes
  api_id               = aws_apigatewayv2_api.api.id
  route_key            = each.key
  target               = "integrations/${aws_apigatewayv2_integration.backend.id}"
  authorization_type   = "JWT"
  authorizer_id        = aws_apigatewayv2_authorizer.jwt.id
  authorization_scopes = each.value
}
resource "aws_cloudwatch_log_group" "api" {
  name              = "/apigateway/${local.name}"
  retention_in_days = var.environment == "prod" ? 90 : 14
}
resource "aws_apigatewayv2_stage" "main" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
  default_route_settings {
    throttling_burst_limit   = 50
    throttling_rate_limit    = 25
    detailed_metrics_enabled = true
  }
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api.arn
    format = jsonencode({
      requestId          = "$context.requestId", route = "$context.routeKey", status = "$context.status",
      integrationLatency = "$context.integrationLatency", integrationStatus = "$context.integration.status",
      integrationError   = "$context.integrationErrorMessage"
    })
  }
}
