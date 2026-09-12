package cl.solicitudes.common;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class ApiExceptionHandler {
    private ResponseEntity<Map<String,Object>> response(HttpStatus status, String message){
        Map<String,Object> body = new LinkedHashMap<>();
        body.put("timestamp", Instant.now().toString()); body.put("status", status.value()); body.put("error", message);
        return ResponseEntity.status(status).body(body);
    }
    @ExceptionHandler(org.springframework.orm.ObjectOptimisticLockingFailureException.class)
    ResponseEntity<Map<String,Object>> concurrentUpdate(Exception e){ return response(HttpStatus.CONFLICT,"Otra persona modificó esta solicitud. Actualiza la lista."); }
    @ExceptionHandler(org.springframework.http.converter.HttpMessageNotReadableException.class)
    ResponseEntity<Map<String,Object>> invalidJson(Exception e){ return response(HttpStatus.BAD_REQUEST,"El cuerpo de la solicitud no es válido"); }
    @ExceptionHandler(NotFoundException.class) ResponseEntity<Map<String,Object>> nf(NotFoundException e){ return response(HttpStatus.NOT_FOUND,e.getMessage()); }
    @ExceptionHandler(ConflictException.class) ResponseEntity<Map<String,Object>> conflict(ConflictException e){ return response(HttpStatus.CONFLICT,e.getMessage()); }
    @ExceptionHandler(ForbiddenException.class) ResponseEntity<Map<String,Object>> forbidden(ForbiddenException e){ return response(HttpStatus.FORBIDDEN,e.getMessage()); }
    @ExceptionHandler(IllegalArgumentException.class) ResponseEntity<Map<String,Object>> bad(IllegalArgumentException e){ return response(HttpStatus.BAD_REQUEST,e.getMessage()); }
    @ExceptionHandler(MethodArgumentNotValidException.class) ResponseEntity<Map<String,Object>> validation(MethodArgumentNotValidException e){
        String msg=e.getBindingResult().getFieldErrors().stream().findFirst().map(x->x.getField()+": "+x.getDefaultMessage()).orElse("Solicitud inválida");
        return response(HttpStatus.BAD_REQUEST,msg);
    }
}
