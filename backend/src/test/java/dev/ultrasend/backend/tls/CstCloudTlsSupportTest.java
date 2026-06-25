package dev.ultrasend.backend.tls;

import org.junit.jupiter.api.Test;

import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLSocket;
import javax.net.ssl.TrustManager;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class CstCloudTlsSupportTest {

    @Test
    void needsSupplementalTrustForCstcloudHosts() {
        assertTrue(CstCloudTlsSupport.needsSupplementalTrust("https://s3.cstcloud.cn"));
        assertTrue(CstCloudTlsSupport.needsSupplementalTrust("https://s3.data.cstcloud.cn"));
        assertTrue(CstCloudTlsSupport.needsSupplementalTrust("https://data.cstcloud.cn/dav"));
        assertFalse(CstCloudTlsSupport.needsSupplementalTrust("https://s3.amazonaws.com"));
        assertFalse(CstCloudTlsSupport.needsSupplementalTrust(null));
        assertFalse(CstCloudTlsSupport.needsSupplementalTrust(""));
    }

    @Test
    void trustManagersForNonCstcloudReturnsNull() {
        assertNull(CstCloudTlsSupport.trustManagersFor("https://s3.bitiful.net"));
    }

    @Test
    void trustManagersForCstcloudCanHandshake() throws Exception {
        TrustManager[] trustManagers = CstCloudTlsSupport.trustManagersFor("https://s3.cstcloud.cn");
        assertNotNull(trustManagers);
        SSLContext ctx = SSLContext.getInstance("TLS");
        ctx.init(null, trustManagers, null);
        try (SSLSocket socket = (SSLSocket) ctx.getSocketFactory().createSocket("s3.cstcloud.cn", 443)) {
            socket.startHandshake();
        }
    }

    @Test
    void sslContextForDataCapsuleWebDavCanHandshake() throws Exception {
        SSLContext ctx = CstCloudTlsSupport.sslContextFor("https://data.cstcloud.cn/dav");
        assertNotNull(ctx);
        try (SSLSocket socket = (SSLSocket) ctx.getSocketFactory().createSocket("data.cstcloud.cn", 443)) {
            socket.startHandshake();
        }
    }

    @Test
    void isSslProbeErrorDetectsPkixMessages() {
        assertTrue(CstCloudTlsSupport.isSslProbeError(
                "Unable to execute HTTP request: PKIX path building failed", null));
        assertFalse(CstCloudTlsSupport.isSslProbeError("The request signature we calculated does not match", null));
    }
}
