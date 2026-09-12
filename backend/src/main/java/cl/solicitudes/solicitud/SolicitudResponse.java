package cl.solicitudes.solicitud;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

public record SolicitudResponse(UUID id,String solicitanteId,String solicitanteNombre,TipoSolicitud tipo,String titulo,String descripcion,
    LocalDate fechaInicio,LocalDate fechaFin,EstadoSolicitud estado,String comentarioAprobador,String aprobadorNombre,
    Instant creadoEn,Instant actualizadoEn,Instant decididoEn) {
    static SolicitudResponse from(Solicitud s){ return new SolicitudResponse(s.getId(),s.getSolicitanteId(),s.getSolicitanteNombre(),s.getTipo(),s.getTitulo(),s.getDescripcion(),s.getFechaInicio(),s.getFechaFin(),s.getEstado(),s.getComentarioAprobador(),s.getAprobadorNombre(),s.getCreadoEn(),s.getActualizadoEn(),s.getDecididoEn()); }
}
