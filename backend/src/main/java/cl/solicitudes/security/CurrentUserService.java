package cl.solicitudes.security;

import java.util.*;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/** Identidad de Gateway; NO lee, decodifica ni valida el JWT. */
@Component
public class CurrentUserService {
    private final String mode;
    private final ObjectProvider<HttpServletRequest> requests;
    public CurrentUserService(@Value("${app.identity-mode:gateway}") String mode,
                              ObjectProvider<HttpServletRequest> requests) {
        if(!Set.of("gateway","demo").contains(mode)) throw new IllegalArgumentException("Modo de identidad inválido");
        this.mode=mode; this.requests=requests;
    }
    public CurrentUser get() {
        if("demo".equals(mode)){
            String id=header("X-Demo-User","solicitante.demo");
            String role=header("X-Demo-Role","SOLICITANTE").toUpperCase(Locale.ROOT);
            if(!Set.of("SOLICITANTE","APROBADOR").contains(role)) throw new IllegalArgumentException("Rol demo inválido");
            return new CurrentUser(id,header("X-Demo-Name",id),id+"@local.test",Set.of(role));
        }
        String id=header("X-Verified-User","");
        String scopes=header("X-Verified-Scopes","");
        if(id.isBlank()||scopes.isBlank()) throw new IllegalStateException("Falta identidad de Gateway");
        Set<String> roles=new HashSet<>();
        Set<String> granted=new HashSet<>(Arrays.asList(scopes.split("\\s+")));
        if(granted.contains("solicitudes/write")) roles.add("SOLICITANTE");
        if(granted.contains("solicitudes/approve")) roles.add("APROBADOR");
        return new CurrentUser(id,header("X-Verified-Name",id),"",Set.copyOf(roles));
    }
    private String header(String key,String fallback){
        HttpServletRequest r=requests.getIfAvailable();
        String v=r==null?null:r.getHeader(key);
        return v==null||v.isBlank()?fallback:v.trim();
    }
}
