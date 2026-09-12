package cl.solicitudes.solicitud;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SolicitudRepository extends JpaRepository<Solicitud,UUID> {
    List<Solicitud> findAllBySolicitanteIdOrderByCreadoEnDesc(String id);
    List<Solicitud> findAllByEstadoOrderByCreadoEnAsc(EstadoSolicitud estado);
    long countBySolicitanteIdAndEstado(String id, EstadoSolicitud estado);
    long countByEstado(EstadoSolicitud estado);
    long countBySolicitanteId(String id);
}
