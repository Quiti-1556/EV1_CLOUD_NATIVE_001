package cl.solicitudes.solicitud;
import java.util.*;
import cl.solicitudes.security.*;
import cl.solicitudes.common.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
class SolicitudServiceTest {
    SolicitudRepository repo; CurrentUserService users; SolicitudService service;
    @BeforeEach void setup(){ repo=mock(SolicitudRepository.class);users=mock(CurrentUserService.class);service=new SolicitudService(repo,users); }
    void user(String id,String... roles){when(users.get()).thenReturn(new CurrentUser(id,id,id+"@test.invalid",Set.of(roles)));}
    Solicitud request(String owner){var s=new Solicitud();s.setId(UUID.randomUUID());s.setSolicitanteId(owner);s.setEstado(EstadoSolicitud.PENDIENTE);when(repo.findById(s.getId())).thenReturn(Optional.of(s));return s;}
    @Test void preventsReadingAndDeletingAnotherUsersRequest(){user("alice","SOLICITANTE");var s=request("bob");assertThrows(ForbiddenException.class,()->service.obtener(s.getId()));assertThrows(ForbiddenException.class,()->service.eliminar(s.getId()));verify(repo,never()).delete(any());}
    @Test void preventsSelfApprovalEvenWithBothRoles(){user("alice","SOLICITANTE","APROBADOR");var s=request("alice");assertThrows(ForbiddenException.class,()->service.decidir(s.getId(),new DecisionRequest(DecisionRequest.Decision.APROBAR,"válida")));}
    @Test void preventsDecisionsWithoutApproverRole(){user("alice","SOLICITANTE");var s=request("bob");assertThrows(ForbiddenException.class,()->service.decidir(s.getId(),new DecisionRequest(DecisionRequest.Decision.RECHAZAR,"motivo")));}
    @Test void preventsSecondDecision(){user("approver","APROBADOR");var s=request("bob");s.setEstado(EstadoSolicitud.APROBADA);assertThrows(ConflictException.class,()->service.decidir(s.getId(),new DecisionRequest(DecisionRequest.Decision.RECHAZAR,"motivo")));}
    @Test void scopesSummaryToOwner(){user("alice","SOLICITANTE");service.resumen();verify(repo,never()).countByEstado(any());verify(repo).countBySolicitanteIdAndEstado("alice",EstadoSolicitud.PENDIENTE);}
    @Test void permitsApproverDecisionAndRecordsActor(){user("approver","APROBADOR");var s=request("bob");when(repo.save(any())).thenAnswer(i->i.getArgument(0));service.decidir(s.getId(),new DecisionRequest(DecisionRequest.Decision.APROBAR,"Aceptado"));assertEquals(EstadoSolicitud.APROBADA,s.getEstado());assertEquals("approver",s.getAprobadorId());assertNotNull(s.getDecididoEn());}
}
