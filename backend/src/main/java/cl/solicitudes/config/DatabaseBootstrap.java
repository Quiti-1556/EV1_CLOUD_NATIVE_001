package cl.solicitudes.config;

import java.sql.SQLException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;

/** Separación de credenciales: solo la tarea efímera usa el propietario RDS. */
@Configuration
@ConditionalOnProperty(name = "app.bootstrap.enabled", havingValue = "true")
public class DatabaseBootstrap {

    private static final Logger LOGGER = LoggerFactory.getLogger(DatabaseBootstrap.class);

    @Bean
    ApplicationRunner provisionApplicationRole(
            JdbcTemplate jdbc,
            @Value("${app.bootstrap.password}") String password,
            ConfigurableApplicationContext context) {

        return args -> {
            String stage = "verificar conexión y privilegios";

            try {
                String currentUser = jdbc.queryForObject("SELECT current_user", String.class);
                String currentDatabase = jdbc.queryForObject("SELECT current_database()", String.class);
                Boolean canCreateRole = jdbc.queryForObject(
                        "SELECT rolcreaterole FROM pg_roles WHERE rolname = current_user",
                        Boolean.class
                );

                LOGGER.info(
                        "Bootstrap PostgreSQL iniciado: database={}, user={}, canCreateRole={}",
                        currentDatabase,
                        currentUser,
                        canCreateRole
                );

                if (!Boolean.TRUE.equals(canCreateRole)) {
                    throw new IllegalStateException(
                            "El usuario maestro configurado no tiene CREATEROLE"
                    );
                }

                // Password pasado como parámetro; format(%L) realiza escaping PostgreSQL.
                stage = "consultar rol solicitudes_app";
                Boolean exists = jdbc.queryForObject(
                        "SELECT EXISTS(SELECT 1 FROM pg_roles WHERE rolname = 'solicitudes_app')",
                        Boolean.class
                );

                stage = Boolean.TRUE.equals(exists)
                        ? "actualizar rol solicitudes_app"
                        : "crear rol solicitudes_app";

                String command = jdbc.queryForObject(
                        Boolean.TRUE.equals(exists)
                                ? "SELECT format('ALTER ROLE solicitudes_app LOGIN NOCREATEDB NOCREATEROLE PASSWORD %L', ?)"
                                : "SELECT format('CREATE ROLE solicitudes_app LOGIN NOCREATEDB NOCREATEROLE PASSWORD %L', ?)",
                        String.class,
                        password
                );
                jdbc.execute(command);

                stage = "revocar CREATE público";
                jdbc.execute("REVOKE CREATE ON SCHEMA public FROM PUBLIC");

                stage = "conceder CONNECT";
                jdbc.execute("GRANT CONNECT ON DATABASE solicitudes TO solicitudes_app");

                stage = "conceder USAGE del schema";
                jdbc.execute("GRANT USAGE ON SCHEMA public TO solicitudes_app");

                stage = "conceder permisos de tabla";
                jdbc.execute("GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE solicitudes TO solicitudes_app");
                // No permisos DDL, historial de Flyway ni administración de roles.
            } catch (Exception failure) {
                Throwable root = failure;
                while (root.getCause() != null && root.getCause() != root) {
                    root = root.getCause();
                }

                String detail = root.getMessage() == null
                        ? "sin detalle"
                        : root.getMessage();
                if (password != null && !password.isBlank()) {
                    detail = detail.replace(password, "[REDACTED]");
                }

                if (root instanceof SQLException sqlFailure) {
                    LOGGER.error(
                            "Falló bootstrap PostgreSQL en '{}': SQLState={}, errorCode={}, detalle={}",
                            stage,
                            sqlFailure.getSQLState(),
                            sqlFailure.getErrorCode(),
                            detail
                    );
                } else {
                    LOGGER.error(
                            "Falló bootstrap PostgreSQL en '{}': tipo={}, detalle={}",
                            stage,
                            root.getClass().getName(),
                            detail
                    );
                }

                System.exit(SpringApplication.exit(context, () -> 1));
                return;
            }

            LOGGER.info("Migraciones y permisos de aplicación completados");
            System.exit(SpringApplication.exit(context, () -> 0));
        };
    }
}
