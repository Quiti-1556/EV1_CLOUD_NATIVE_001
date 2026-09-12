package cl.solicitudes.solicitud;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import cl.solicitudes.common.*;
import cl.solicitudes.security.CurrentUser;
import cl.solicitudes.security.CurrentUserService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class SolicitudService {
    private final SolicitudRepository repo; private final CurrentUserService users;
    public SolicitudService(SolicitudRepository repo,CurrentUserService users){this.repo=repo;this.users=users;}
    @Transactional public SolicitudResponse crear(SolicitudRequest r){
        CurrentUser u=users.get(); requireSolicitante(u); validateDates(r);
        Instant now=Instant.now(); Solicitud s=new Solicitud(); s.setId(UUID.randomUUID()); s.setSolicitanteId(u.id()); s.setSolicitanteNombre(u.nombre());
        apply(s,r); s.setEstado(EstadoSolicitud.PENDIENTE); s.setCreadoEn(now); s.setActualizadoEn(now); return SolicitudResponse.from(repo.save(s));
    }
    @Transactional(readOnly=true) public List<SolicitudResponse> mias(){ CurrentUser u=users.get(); return repo.findAllBySolicitanteIdOrderByCreadoEnDesc(u.id()).stream().map(SolicitudResponse::from).toList(); }
    @Transactional(readOnly=true) public List<SolicitudResponse> pendientes(){ requireAprobador(users.get()); return repo.findAllByEstadoOrderByCreadoEnAsc(EstadoSolicitud.PENDIENTE).stream().map(SolicitudResponse::from).toList(); }
    @Transactional(readOnly=true) public SolicitudResponse obtener(UUID id){ Solicitud s=get(id); CurrentUser u=users.get(); if(!u.hasRole("APROBADOR")&&!s.getSolicitanteId().equals(u.id())) throw new ForbiddenException("No puedes ver solicitudes de otro usuario"); return SolicitudResponse.from(s); }
    @Transactional public SolicitudResponse actualizar(UUID id,SolicitudRequest r){ CurrentUser u=users.get(); Solicitud s=get(id); ensureOwnerPending(s,u); validateDates(r); apply(s,r); s.setActualizadoEn(Instant.now()); return SolicitudResponse.from(repo.save(s)); }
    @Transactional public void eliminar(UUID id){ CurrentUser u=users.get(); Solicitud s=get(id); ensureOwnerPending(s,u); repo.delete(s); }
    @Transactional public SolicitudResponse decidir(UUID id,DecisionRequest r){
        CurrentUser u=users.get(); requireAprobador(u); Solicitud s=get(id); if(s.getSolicitanteId().equals(u.id())) throw new ForbiddenException("No puedes resolver tu propia solicitud"); if(s.getEstado()!=EstadoSolicitud.PENDIENTE) throw new ConflictException("La solicitud ya fue resuelta");
        s.setEstado(r.decision()==DecisionRequest.Decision.APROBAR?EstadoSolicitud.APROBADA:EstadoSolicitud.RECHAZADA); s.setComentarioAprobador(r.comentario().trim());
        s.setAprobadorId(u.id()); s.setAprobadorNombre(u.nombre()); s.setDecididoEn(Instant.now()); s.setActualizadoEn(Instant.now()); return SolicitudResponse.from(repo.save(s));
    }
    @Transactional(readOnly=true) public Resumen resumen(){ CurrentUser u=users.get(); long pending=count(u,EstadoSolicitud.PENDIENTE), approved=count(u,EstadoSolicitud.APROBADA), rejected=count(u,EstadoSolicitud.RECHAZADA); return new Resumen(pending,approved,rejected,repo.countBySolicitanteId(u.id()),u.roles()); }
    private long count(CurrentUser u, EstadoSolicitud estado){ return u.hasRole("APROBADOR") ? repo.countByEstado(estado) : repo.countBySolicitanteIdAndEstado(u.id(),estado); }
    private Solicitud get(UUID id){ return repo.findById(id).orElseThrow(()->new NotFoundException("Solicitud no encontrada")); }
    private void apply(Solicitud s,SolicitudRequest r){ s.setTipo(r.tipo()); s.setTitulo(r.titulo().trim()); s.setDescripcion(r.descripcion().trim()); s.setFechaInicio(r.fechaInicio()); s.setFechaFin(r.fechaFin()); }
    private void validateDates(SolicitudRequest r){ if(r.fechaInicio()!=null&&r.fechaFin()!=null&&r.fechaFin().isBefore(r.fechaInicio())) throw new IllegalArgumentException("fechaFin no puede ser anterior a fechaInicio"); }
    private void ensureOwnerPending(Solicitud s,CurrentUser u){ requireSolicitante(u); if(!s.getSolicitanteId().equals(u.id())) throw new ForbiddenException("Solo el solicitante dueño puede modificarla"); if(s.getEstado()!=EstadoSolicitud.PENDIENTE) throw new ConflictException("Solo se pueden modificar solicitudes pendientes"); }
    private void requireSolicitante(CurrentUser u){ if(!u.hasRole("SOLICITANTE")) throw new ForbiddenException("Se requiere rol SOLICITANTE"); }
    private void requireAprobador(CurrentUser u){ if(!u.hasRole("APROBADOR")) throw new ForbiddenException("Se requiere rol APROBADOR"); }
    public record Resumen(long pendientes,long aprobadas,long rechazadas,long mias,java.util.Set<String> roles){}
}
