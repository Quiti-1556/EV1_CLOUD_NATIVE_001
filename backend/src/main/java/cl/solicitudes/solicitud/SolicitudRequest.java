package cl.solicitudes.solicitud;

import java.time.LocalDate;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record SolicitudRequest(
    @NotNull TipoSolicitud tipo,
    @NotBlank @Size(max=140) String titulo,
    @NotBlank @Size(max=2000) String descripcion,
    LocalDate fechaInicio,
    LocalDate fechaFin
) {}
