resource "aws_amplify_app" "front" {
  name                     = local.name
  platform                 = "WEB"
  enable_branch_auto_build = false
  # Permitir Gateway de esta región evita un ciclo: Gateway CORS usa el dominio Amplify.
  custom_headers = yamlencode({ customHeaders = [{ pattern = "**/*", headers = [
    { key = "Strict-Transport-Security", value = "max-age=31536000; includeSubDomains" },
    { key = "X-Frame-Options", value = "DENY" },
    { key = "Content-Security-Policy", value = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self' https://*.execute-api.${var.aws_region}.amazonaws.com; object-src 'none'; base-uri 'self'; frame-ancestors 'none'" },
    { key = "X-Content-Type-Options", value = "nosniff" },
    { key = "Referrer-Policy", value = "no-referrer" },
    { key = "Permissions-Policy", value = "camera=(), microphone=(), geolocation=(), payment=()" },
    { key = "Cache-Control", value = "no-store" }
  ] }] })
}
resource "aws_amplify_branch" "main" {
  app_id            = aws_amplify_app.front.id
  branch_name       = var.frontend_branch
  framework         = "Angular"
  stage             = var.environment == "prod" ? "PRODUCTION" : "DEVELOPMENT"
  enable_auto_build = false
}
