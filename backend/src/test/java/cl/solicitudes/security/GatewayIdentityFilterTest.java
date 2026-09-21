package cl.solicitudes.security;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.*;
import static org.junit.jupiter.api.Assertions.*;
class GatewayIdentityFilterTest{
 @Test void missingIdentity401()throws Exception{
  var r=new MockHttpServletRequest("GET","/datos");r.addHeader("Authorization","Bearer dummy");
  var s=new MockHttpServletResponse();new GatewayIdentityFilter("gateway").doFilter(r,s,(a,b)->fail("No llega al controlador"));
  assertEquals(401,s.getStatus());
 }
 @Test void trustedIdentityAcceptsWithoutAnyToken()throws Exception{
  var r=new MockHttpServletRequest("GET","/datos");r.addHeader("X-Verified-User","alice");r.addHeader("X-Verified-Scopes","solicitudes/read");r.addHeader("X-Gateway-Request-Id","gateway-123");
  var s=new MockHttpServletResponse();boolean[] reached={false};new GatewayIdentityFilter("gateway").doFilter(r,s,(a,b)->reached[0]=true);
  assertTrue(reached[0]);assertEquals("gateway-123",s.getHeader("X-Request-Id"));
 }
 @Test void healthAvailableButUnknownRoutes404()throws Exception{
  boolean[] reached={false};new GatewayIdentityFilter("gateway").doFilter(new MockHttpServletRequest("GET","/actuator/health"),new MockHttpServletResponse(),(a,b)->reached[0]=true);assertTrue(reached[0]);
  var s=new MockHttpServletResponse();new GatewayIdentityFilter("gateway").doFilter(new MockHttpServletRequest("GET","/admin"),s,(a,b)->fail("Ruta desconocida"));
  assertEquals(404,s.getStatus());
 }
}
