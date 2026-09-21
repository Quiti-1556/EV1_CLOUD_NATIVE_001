package cl.solicitudes.security;
import java.io.IOException;
import jakarta.servlet.*;
import jakarta.servlet.http.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnWebApplication;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
/** Fail-closed ante integración incompleta. NO autentica ni valida tokens. */
@Component
@ConditionalOnWebApplication(type=ConditionalOnWebApplication.Type.SERVLET)
public class GatewayIdentityFilter extends OncePerRequestFilter {
    private final String mode;
    public GatewayIdentityFilter(@Value("${app.identity-mode:gateway}") String mode){this.mode=mode;}
    @Override protected void doFilterInternal(HttpServletRequest r,HttpServletResponse s,FilterChain chain) throws ServletException,IOException {
        String p=r.getRequestURI();
        if(p.equals("/actuator/health")||p.startsWith("/actuator/health/")){chain.doFilter(r,s);return;}
        if(!(p.equals("/datos")||p.equals("/solicitudes")||p.startsWith("/solicitudes/")||p.equals("/productos")||p.startsWith("/productos/"))){s.sendError(404);return;}
        if(!"demo".equals(mode)){
            String user=r.getHeader("X-Verified-User"),scopes=r.getHeader("X-Verified-Scopes");
            if(user==null||user.isBlank()||scopes==null||scopes.isBlank()){
                s.setStatus(401);s.setContentType("application/json");
                s.getWriter().write("{\"error\":\"Falta identidad verificada de API Gateway\"}");return;
            }
        }
        String id=r.getHeader("X-Gateway-Request-Id");
        if(id!=null&&id.matches("[A-Za-z0-9_=.-]{1,128}"))s.setHeader("X-Request-Id",id);
        chain.doFilter(r,s);
    }
}
