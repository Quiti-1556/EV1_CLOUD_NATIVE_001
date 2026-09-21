resource "aws_cognito_user_pool" "users" {
  name                     = local.name
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]
  deletion_protection      = var.deletion_protection ? "ACTIVE" : "INACTIVE"
  user_pool_tier           = "ESSENTIALS"
  mfa_configuration        = "ON"
  software_token_mfa_configuration {
    enabled = true
  }
  admin_create_user_config {
    allow_admin_create_user_only = true
  }
  password_policy {
    minimum_length                   = 14
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 1
  }
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  lambda_config {
    pre_token_generation_config {
      lambda_arn     = aws_lambda_function.user_token_ms.arn
      lambda_version = "V2_0"
    }
  }

  depends_on = [aws_lambda_permission.cognito_user_token_ms]
}
resource "aws_cognito_user_pool_domain" "login" {
  domain       = "${local.name}-${data.aws_caller_identity.current.account_id}"
  user_pool_id = aws_cognito_user_pool.users.id
}
resource "aws_cognito_user_pool_client" "web" {
  name                                 = "${local.name}-web"
  user_pool_id                         = aws_cognito_user_pool.users.id
  generate_secret                      = false
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  # El frontend solicita solo OIDC. El trigger V2 agrega estos permisos
  # dinámicamente según el grupo del usuario.
  allowed_oauth_scopes = [
    "openid",
    "email",
    "profile",
    "${aws_cognito_resource_server.solicitudes.identifier}/read",
    "${aws_cognito_resource_server.solicitudes.identifier}/write",
    "${aws_cognito_resource_server.solicitudes.identifier}/approve"
  ]
  supported_identity_providers  = ["COGNITO"]
  callback_urls                 = ["${aws_apigatewayv2_api.api.api_endpoint}/auth/callback"]
  logout_urls                   = [for origin in local.origins : "${origin}/"]
  prevent_user_existence_errors = "ENABLED"
  enable_token_revocation       = true
  access_token_validity         = 15
  id_token_validity             = 15
  refresh_token_validity        = 1
  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
  explicit_auth_flows = ["ALLOW_USER_AUTH"]
  refresh_token_rotation {
    feature                    = "ENABLED"
    retry_grace_period_seconds = 10
  }
}
resource "aws_cognito_user_group" "roles" {
  for_each     = toset(["SOLICITANTE", "APROBADOR"])
  name         = each.key
  user_pool_id = aws_cognito_user_pool.users.id
}

resource "aws_cognito_resource_server" "solicitudes" {
  user_pool_id = aws_cognito_user_pool.users.id
  identifier   = "solicitudes"
  name         = "API de solicitudes"

  scope {
    scope_name        = "read"
    scope_description = "Consultar solicitudes y resumen"
  }
  scope {
    scope_name        = "write"
    scope_description = "Crear, modificar y eliminar solicitudes propias"
  }
  scope {
    scope_name        = "approve"
    scope_description = "Aprobar o rechazar solicitudes"
  }
}
