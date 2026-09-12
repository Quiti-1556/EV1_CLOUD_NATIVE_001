package cl.solicitudes.datos;

import cl.solicitudes.solicitud.SolicitudService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class DatosController {
    private final SolicitudService service; public DatosController(SolicitudService s){service=s;}
    @GetMapping("/datos") public SolicitudService.Resumen datos(){return service.resumen();}
}
