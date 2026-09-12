package cl.solicitudes.solicitud;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record DecisionRequest(@NotNull Decision decision, @NotBlank @Size(max=1000) String comentario) {
    public enum Decision { APROBAR, RECHAZAR }
}
