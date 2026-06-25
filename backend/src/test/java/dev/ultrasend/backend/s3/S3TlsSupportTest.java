package dev.ultrasend.backend.s3;

import org.junit.jupiter.api.Test;

import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLSocket;
import javax.net.ssl.TrustManager;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class S3TlsSupportTest {

    @Test
    void needsSupplementalTrustForCstcloudHosts() {
        assertTrue(S3TlsSupport.needsSupplementalTrust("https://s3.cstcloud.cn"));
        assertTrue(S3TlsSupport.needsSupplementalTrust("https://s3.data.cstcloud.cn"));
        assertFalse(S3TlsSupport.needsSupplementalTrust("https://s3.amazonaws.com"));
        assertFalse(S3TlsSupport.needsSupplementalTrust(null));
        assertFalse(S3TlsSupport.needsSupplementalTrust(""));
    }

    @Test
    void trustManagersForNonCstcloudReturnsNull() {
        assertNull(S3TlsSupport.trustManagersFor("https://s3.bitiful.net"));
    }

    @Test
    void trustManagersForCstcloudCanHandshake() throws Exception {
        TrustManager[] trustManagers = S3TlsSupport.trustManagersFor("https://s3.cstcloud.cn");
        assertNotNull(trustManagers);
        SSLContext ctx = SSLContext.getInstance("TLS");
        ctx.init(null, trustManagers, null);
        try (SSLSocket socket = (SSLSocket) ctx.getSocketFactory().createSocket("s3.cstcloud.cn", 443)) {
            socket.startHandshake();
        }
    }

    @Test
    void isSslProbeErrorDetectsPkixMessages() {
        assertTrue(S3TlsSupport.isSslProbeError(
                "Unable to execute HTTP request: PKIX path building failed", null));
        assertFalse(S3TlsSupport.isSslProbeError("The request signature we calculated does not match", null));
    }
}
