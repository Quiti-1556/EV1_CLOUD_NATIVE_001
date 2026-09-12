package cl.solicitudes.config;

import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnWebApplication;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import cl.solicitudes.security.CognitoAccessTokenValidator;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;


@Configuration
@EnableWebSecurity
@ConditionalOnProperty(
    name = "app.security.enabled",
    havingValue = "true",
    matchIfMissing = true
)
@ConditionalOnWebApplication(type = ConditionalOnWebApplication.Type.SERVLET)
public class SecurityConfig {
    @Bean
    @ConditionalOnProperty(name="app.security.enabled",havingValue="true",matchIfMissing=true)
    JwtDecoder jwtDecoder(@Value("${app.security.issuer-uri:}") String issuer, @Value("${app.security.client-id:}") String clientId){
        if(issuer==null||issuer.isBlank()) throw new IllegalStateException("APP_SECURITY_ENABLED=true requiere COGNITO_ISSUER_URI");
        if(clientId == null || clientId.isBlank()) throw new IllegalStateException("Falta COGNITO_CLIENT_ID");
        NimbusJwtDecoder decoder = NimbusJwtDecoder.withJwkSetUri(issuer + "/.well-known/jwks.json").build();
        decoder.setJwtValidator(new DelegatingOAuth2TokenValidator<>(
            JwtValidators.createDefaultWithIssuer(issuer), new CognitoAccessTokenValidator(clientId)));
        return decoder;
    }
    @Bean
    JwtAuthenticationConverter jwtAuthenticationConverter(){
        JwtAuthenticationConverter c=new JwtAuthenticationConverter();
        c.setJwtGrantedAuthoritiesConverter(jwt->{
            Set<org.springframework.security.core.GrantedAuthority> out=new HashSet<>();
            Object groups=jwt.getClaims().get("cognito:groups");
            if(groups instanceof Iterable<?> it) for(Object g:it) out.add(new SimpleGrantedAuthority("ROLE_"+String.valueOf(g).toUpperCase()));
            String scope=jwt.getClaimAsString("scope");
            if(scope!=null) Arrays.stream(scope.split("\\s+")).filter(s->!s.isBlank()).forEach(s->out.add(new SimpleGrantedAuthority("SCOPE_"+s)));
            return out;
        });
        return c;
    }
    @Bean
    SecurityFilterChain filter(HttpSecurity http,
        @Value("${app.security.enabled:true}") boolean enabled,
        JwtAuthenticationConverter converter) throws Exception {
        http.csrf(x->x.disable()).cors(Customizer.withDefaults())
            .sessionManagement(x->x.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .headers(h->h.contentTypeOptions(Customizer.withDefaults()).frameOptions(f->f.deny()).httpStrictTransportSecurity(s->s.includeSubDomains(true).maxAgeInSeconds(31536000)))
            .authorizeHttpRequests(a->{
                a.requestMatchers(HttpMethod.OPTIONS,"/**").permitAll();
                a.requestMatchers("/actuator/health","/actuator/health/**").permitAll();
                if(!enabled){ a.requestMatchers("/datos/**","/solicitudes/**","/productos/**").permitAll(); }
                else {
                    a.requestMatchers("/solicitudes/pendientes","/productos/pendientes").hasRole("APROBADOR");
                    a.requestMatchers(HttpMethod.POST,"/solicitudes/*/decision","/productos/*/decision").hasRole("APROBADOR");
                    a.requestMatchers("/datos/**","/solicitudes/**","/productos/**").hasAnyRole("SOLICITANTE", "APROBADOR");
                }
                a.anyRequest().denyAll();
            });
        if(enabled) http.oauth2ResourceServer(o->o.jwt(j->j.jwtAuthenticationConverter(converter)));
        return http.build();
    }
    @Bean
    CorsConfigurationSource cors(@Value("${app.cors.allowed-origins:http://localhost:4200}") String origins){
        List<String> allowed=Arrays.stream(origins.split(",")).map(String::trim).filter(s->!s.isBlank()).toList();
        if(allowed.stream().anyMatch("*"::equals)) throw new IllegalStateException("CORS_ALLOWED_ORIGINS no puede contener *");
        CorsConfiguration c=new CorsConfiguration(); c.setAllowedOrigins(allowed);
        c.setAllowedMethods(List.of("GET","POST","PUT","DELETE","OPTIONS"));
        c.setAllowedHeaders(List.of("Authorization","Content-Type","Accept","X-Demo-User","X-Demo-Role","X-Demo-Name"));
        c.setExposedHeaders(List.of("Location")); c.setAllowCredentials(false); c.setMaxAge(3600L);
        UrlBasedCorsConfigurationSource s=new UrlBasedCorsConfigurationSource(); s.registerCorsConfiguration("/**",c); return s;
    }
}
