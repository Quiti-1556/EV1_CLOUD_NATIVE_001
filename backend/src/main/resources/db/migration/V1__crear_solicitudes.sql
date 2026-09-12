CREATE TABLE solicitudes (
    id UUID PRIMARY KEY,
    solicitante_id VARCHAR(160) NOT NULL,
    solicitante_nombre VARCHAR(180) NOT NULL,
    tipo VARCHAR(30) NOT NULL CHECK (tipo IN ('VACACIONES','PERMISO','COMPRA','TELETRABAJO','OTRO')),
    titulo VARCHAR(140) NOT NULL,
    descripcion VARCHAR(2000) NOT NULL,
    fecha_inicio DATE,
    fecha_fin DATE,
    estado VARCHAR(20) NOT NULL CHECK (estado IN ('PENDIENTE','APROBADA','RECHAZADA')),
    comentario_aprobador VARCHAR(1000),
    aprobador_id VARCHAR(160),
    aprobador_nombre VARCHAR(180),
    creado_en TIMESTAMPTZ NOT NULL,
    actualizado_en TIMESTAMPTZ NOT NULL,
    decidido_en TIMESTAMPTZ,
    version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT ck_fechas CHECK (fecha_fin IS NULL OR fecha_inicio IS NULL OR fecha_fin >= fecha_inicio),
    CONSTRAINT ck_decision CHECK ((estado='PENDIENTE' AND decidido_en IS NULL) OR (estado<>'PENDIENTE' AND decidido_en IS NOT NULL))
);
CREATE INDEX idx_sol_estado ON solicitudes(estado);
CREATE INDEX idx_sol_solicitante ON solicitudes(solicitante_id);
CREATE INDEX idx_sol_creado ON solicitudes(creado_en DESC);
