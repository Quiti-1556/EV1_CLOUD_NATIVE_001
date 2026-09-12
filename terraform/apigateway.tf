resource "aws_apigatewayv2_api" "api" {
  name          = local.name
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins  = local.origins
    allow_methods  = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers  = ["authorization", "content-type", "accept", "cache-control", "pragma", "x-requested-with"]
    expose_headers = ["location"]
    max_age        = 600
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
  request_parameters     = { "overwrite:path" = "$request.path" }
  timeout_milliseconds   = 29000
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
  # No usar ANY: también capturaría OPTIONS y obligaría al preflight CORS a
  # presentar un JWT. API Gateway atiende automáticamente los OPTIONS que no
  # tienen una ruta explícita cuando cors_configuration está habilitado.
  api_routes = {
    "GET /datos" = ["solicitudes/read"]

    "GET /solicitudes"             = ["solicitudes/read"]
    "GET /solicitudes/{proxy+}"    = ["solicitudes/read"]
    "POST /solicitudes"            = ["solicitudes/write"]
    "PUT /solicitudes/{proxy+}"    = ["solicitudes/write"]
    "DELETE /solicitudes/{proxy+}" = ["solicitudes/write"]
    "POST /solicitudes/{proxy+}"   = ["solicitudes/approve"]

    # Alias conservado para compatibilidad con el proyecto original.
    "GET /productos"             = ["solicitudes/read"]
    "GET /productos/{proxy+}"    = ["solicitudes/read"]
    "POST /productos"            = ["solicitudes/write"]
    "PUT /productos/{proxy+}"    = ["solicitudes/write"]
    "DELETE /productos/{proxy+}" = ["solicitudes/write"]
    "POST /productos/{proxy+}"   = ["solicitudes/approve"]
  }
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
    format          = jsonencode({ requestId = "$context.requestId", route = "$context.routeKey", status = "$context.status", latency = "$context.responseLatency", integrationError = "$context.integrationErrorMessage" })
  }
}
