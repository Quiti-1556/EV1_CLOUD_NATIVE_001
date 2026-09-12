package cl.solicitudes.security;

import java.util.Collection;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.stereotype.Component;

@Component
public class CurrentUserService {
    private final boolean securityEnabled;
    private final ObjectProvider<HttpServletRequest> requests;

    public CurrentUserService(
            @Value("${app.security.enabled:true}") boolean securityEnabled,
            ObjectProvider<HttpServletRequest> requests) {
        this.securityEnabled = securityEnabled;
        this.requests = requests;
    }
    public CurrentUser get(){
        if(!securityEnabled){
            String id = header("X-Demo-User", "solicitante.demo");
            String role = header("X-Demo-Role", "SOLICITANTE").toUpperCase(Locale.ROOT);
            String name = header("X-Demo-Name", role.equals("APROBADOR") ? "Aprobador Demo" : "Solicitante Demo");
            return new CurrentUser(id,name,id+"@local.test",Set.of(role));
        }
        Authentication a=SecurityContextHolder.getContext().getAuthentication();
        if(!(a instanceof JwtAuthenticationToken jwt)) throw new IllegalStateException("No hay identidad JWT autenticada");
        var token=jwt.getToken();
        String id=token.getSubject();
        String email=first(token.getClaimAsString("email"), first(token.getClaimAsString("username"), id));
        String name=first(token.getClaimAsString("name"), email);
        Set<String> roles=new HashSet<>();
        Object groups=token.getClaims().get("cognito:groups");
        if(groups instanceof Collection<?> c) c.forEach(x ->
                roles.add(String.valueOf(x).toUpperCase(Locale.ROOT)));
        // Sin grupo explícito no se conceden permisos.
        return new CurrentUser(id,name,email,Set.copyOf(roles));
    }
    private String header(String key, String fallback) {
        HttpServletRequest request = requests.getIfAvailable();
        if (request == null) {
            return fallback;
        }
        String value = request.getHeader(key);
        return value == null || value.isBlank() ? fallback : value.trim();
    }
    private String first(String a,String b){ return a==null||a.isBlank()?b:a; }
}
