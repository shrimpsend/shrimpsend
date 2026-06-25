package dev.ultrasend.backend.webdav;

import dev.ultrasend.backend.tls.CstCloudTlsSupport;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;

class WebDavPropfindClientTlsTest {

    @Test
    void cstcloudBaseUrlGetsSupplementalSslContext() {
        assertNotNull(CstCloudTlsSupport.sslContextFor("https://data.cstcloud.cn/dav"));
    }

    @Test
    void nonCstcloudBaseUrlUsesDefaultSslContext() {
        assertNull(CstCloudTlsSupport.sslContextFor("https://dav.example.com"));
    }
}
