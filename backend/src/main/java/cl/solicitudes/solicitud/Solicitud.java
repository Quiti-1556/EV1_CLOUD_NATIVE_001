package cl.solicitudes.solicitud;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;
import jakarta.persistence.*;

@Entity @Table(name="solicitudes", indexes={@Index(name="idx_sol_estado",columnList="estado"),@Index(name="idx_sol_solicitante",columnList="solicitante_id")})
public class Solicitud {
    @Id private UUID id;
    @Column(name="solicitante_id",nullable=false,length=160) private String solicitanteId;
    @Column(name="solicitante_nombre",nullable=false,length=180) private String solicitanteNombre;
    @Enumerated(EnumType.STRING) @Column(nullable=false,length=30) private TipoSolicitud tipo;
    @Column(nullable=false,length=140) private String titulo;
    @Column(nullable=false,length=2000) private String descripcion;
    @Column(name="fecha_inicio") private LocalDate fechaInicio;
    @Column(name="fecha_fin") private LocalDate fechaFin;
    @Enumerated(EnumType.STRING) @Column(nullable=false,length=20) private EstadoSolicitud estado;
    @Column(name="comentario_aprobador",length=1000) private String comentarioAprobador;
    @Column(name="aprobador_id",length=160) private String aprobadorId;
    @Column(name="aprobador_nombre",length=180) private String aprobadorNombre;
    @Column(name="creado_en",nullable=false) private Instant creadoEn;
    @Column(name="actualizado_en",nullable=false) private Instant actualizadoEn;
    @Column(name="decidido_en") private Instant decididoEn;
    @Version private long version;
    public UUID getId(){return id;} public void setId(UUID v){id=v;}
    public String getSolicitanteId(){return solicitanteId;} public void setSolicitanteId(String v){solicitanteId=v;}
    public String getSolicitanteNombre(){return solicitanteNombre;} public void setSolicitanteNombre(String v){solicitanteNombre=v;}
    public TipoSolicitud getTipo(){return tipo;} public void setTipo(TipoSolicitud v){tipo=v;}
    public String getTitulo(){return titulo;} public void setTitulo(String v){titulo=v;}
    public String getDescripcion(){return descripcion;} public void setDescripcion(String v){descripcion=v;}
    public LocalDate getFechaInicio(){return fechaInicio;} public void setFechaInicio(LocalDate v){fechaInicio=v;}
    public LocalDate getFechaFin(){return fechaFin;} public void setFechaFin(LocalDate v){fechaFin=v;}
    public EstadoSolicitud getEstado(){return estado;} public void setEstado(EstadoSolicitud v){estado=v;}
    public String getComentarioAprobador(){return comentarioAprobador;} public void setComentarioAprobador(String v){comentarioAprobador=v;}
    public String getAprobadorId(){return aprobadorId;} public void setAprobadorId(String v){aprobadorId=v;}
    public String getAprobadorNombre(){return aprobadorNombre;} public void setAprobadorNombre(String v){aprobadorNombre=v;}
    public Instant getCreadoEn(){return creadoEn;} public void setCreadoEn(Instant v){creadoEn=v;}
    public Instant getActualizadoEn(){return actualizadoEn;} public void setActualizadoEn(Instant v){actualizadoEn=v;}
    public Instant getDecididoEn(){return decididoEn;} public void setDecididoEn(Instant v){decididoEn=v;}
}
