package cl.solicitudes.solicitud;

import java.net.URI;
import java.util.List;
import java.util.UUID;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping({"/solicitudes","/productos"})
public class SolicitudController {
    private final SolicitudService service; public SolicitudController(SolicitudService s){service=s;}
    @GetMapping public List<SolicitudResponse> mias(){return service.mias();}
    @GetMapping("/mias") public List<SolicitudResponse> misSolicitudes(){return service.mias();}
    @GetMapping("/pendientes") public List<SolicitudResponse> pendientes(){return service.pendientes();}
    @GetMapping("/{id}") public SolicitudResponse obtener(@PathVariable UUID id){return service.obtener(id);}
    @PostMapping public ResponseEntity<SolicitudResponse> crear(@Valid @RequestBody SolicitudRequest r){ SolicitudResponse x=service.crear(r); return ResponseEntity.created(URI.create("/solicitudes/"+x.id())).body(x); }
    @PutMapping("/{id}") public SolicitudResponse actualizar(@PathVariable UUID id,@Valid @RequestBody SolicitudRequest r){return service.actualizar(id,r);}
    @DeleteMapping("/{id}") public ResponseEntity<Void> eliminar(@PathVariable UUID id){service.eliminar(id);return ResponseEntity.noContent().build();}
    @PostMapping("/{id}/decision") public SolicitudResponse decision(@PathVariable UUID id,@Valid @RequestBody DecisionRequest r){return service.decidir(id,r);}
}
