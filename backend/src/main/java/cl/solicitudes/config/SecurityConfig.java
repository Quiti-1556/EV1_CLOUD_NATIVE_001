package cl.solicitudes.config;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnWebApplication;
import org.springframework.web.servlet.config.annotation.*;
/** CORS solo para demo loopback. La producción entra por Gateway y ALB privados. */
@Configuration
@ConditionalOnWebApplication(type=ConditionalOnWebApplication.Type.SERVLET)
public class SecurityConfig implements WebMvcConfigurer {
    private final String mode;
    public SecurityConfig(@Value("${app.identity-mode:gateway}") String mode){this.mode=mode;}
    @Override public void addCorsMappings(CorsRegistry registry){
        if("demo".equals(mode)) registry.addMapping("/**").allowedOrigins("http://localhost:4200")
            .allowedMethods("GET","POST","PUT","DELETE","OPTIONS")
            .allowedHeaders("Content-Type","Accept","X-Demo-User","X-Demo-Role","X-Demo-Name")
            .exposedHeaders("Location","X-Request-Id");
    }
}
