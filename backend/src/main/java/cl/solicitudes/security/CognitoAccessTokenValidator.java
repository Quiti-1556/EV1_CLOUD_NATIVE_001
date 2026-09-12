package cl.solicitudes.security;

import org.springframework.security.oauth2.core.*;
import org.springframework.security.oauth2.jwt.Jwt;

/** Firma/issuer/exp/nbf se validan por Nimbus + JwtValidators. */
public final class CognitoAccessTokenValidator implements OAuth2TokenValidator<Jwt> {
    private final String clientId;
    public CognitoAccessTokenValidator(String clientId) { this.clientId = clientId; }
    @Override public OAuth2TokenValidatorResult validate(Jwt jwt) {
        boolean valid = "access".equals(jwt.getClaimAsString("token_use"))
            && clientId.equals(jwt.getClaimAsString("client_id"))
            && jwt.getSubject() != null && !jwt.getSubject().isBlank()
            && jwt.getExpiresAt() != null;
        return valid ? OAuth2TokenValidatorResult.success()
            : OAuth2TokenValidatorResult.failure(new OAuth2Error("invalid_token", "Access token inválido para esta aplicación", null));
    }
}
