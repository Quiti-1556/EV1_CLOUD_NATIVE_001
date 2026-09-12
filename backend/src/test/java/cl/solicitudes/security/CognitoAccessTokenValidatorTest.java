package cl.solicitudes.security;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.jwt.Jwt;
import static org.junit.jupiter.api.Assertions.*;
class CognitoAccessTokenValidatorTest {
    private Jwt token(String use,String client){ return Jwt.withTokenValue("test").header("alg","RS256")
        .subject("user-1").claim("token_use",use).claim("client_id",client).expiresAt(Instant.now().plusSeconds(60)).build(); }
    @Test void acceptsOnlyAccessTokenForOurClient(){
        var validator=new CognitoAccessTokenValidator("our-client");
        assertFalse(validator.validate(token("access","our-client")).hasErrors());
        assertTrue(validator.validate(token("id","our-client")).hasErrors());
        assertTrue(validator.validate(token("access","other-client")).hasErrors());
    }
}
