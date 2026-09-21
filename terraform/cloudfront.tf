# CloudFront propio retirado intencionalmente.
# Este archivo reemplaza cloudfront.tf al actualizar una copia existente.
# No contiene recursos ni consultas de políticas CloudFront.
# Angular se publica en Amplify y llama directamente a API Gateway con CORS.
# Si hay recursos CloudFront en tu estado anterior, revisa docs/OPERACION.md:
# no borres el estado ni intentes eludir un AccessDenied.
