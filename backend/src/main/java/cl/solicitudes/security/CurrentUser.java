package cl.solicitudes.security;

import java.util.Set;
public record CurrentUser(String id, String nombre, String email, Set<String> roles) {
    public boolean hasRole(String role){ return roles != null && roles.contains(role.toUpperCase()); }
}
