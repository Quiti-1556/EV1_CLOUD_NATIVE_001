package cl.solicitudes.security;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.mock.web.MockHttpServletRequest;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
class CurrentUserServiceTest {
 @SuppressWarnings("unchecked") ObjectProvider<HttpServletRequest> provider(MockHttpServletRequest r){var p=mock(ObjectProvider.class);when(p.getIfAvailable()).thenReturn(r);return p;}
 @Test void usesGatewayScopesAndIgnoresBearerAndDemoHeaders(){
  var r=new MockHttpServletRequest();r.addHeader("X-Verified-User","alice");r.addHeader("X-Verified-Name","Alice");r.addHeader("X-Verified-Scopes","openid solicitudes/read solicitudes/write");
  r.addHeader("Authorization","Bearer not-even-a-jwt");r.addHeader("X-Demo-Role","APROBADOR");
  var u=new CurrentUserService("gateway",provider(r)).get();
  assertEquals("alice",u.id());assertTrue(u.hasRole("SOLICITANTE"));assertFalse(u.hasRole("APROBADOR"));
 }
 @Test void explicitDemoWorksAndGatewayRejectsMissingIdentity(){
  var r=new MockHttpServletRequest();r.addHeader("X-Demo-User","local");r.addHeader("X-Demo-Role","APROBADOR");
  assertTrue(new CurrentUserService("demo",provider(r)).get().hasRole("APROBADOR"));
  assertThrows(IllegalStateException.class,()->new CurrentUserService("gateway",provider(r)).get());
 }
}
