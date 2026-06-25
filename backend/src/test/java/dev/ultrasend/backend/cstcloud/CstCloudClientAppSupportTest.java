package dev.ultrasend.backend.cstcloud;

import dev.ultrasend.backend.s3.S3ProviderId;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class CstCloudClientAppSupportTest {

    @Test
    void resolveS3UserAgent() {
        assertEquals("S3 Browser", CstCloudClientAppSupport.resolveS3UserAgent("s3browser"));
        assertEquals("rclone/v1.67.0", CstCloudClientAppSupport.resolveS3UserAgent("rclone"));
    }

    @Test
    void resolveWebDavUserAgentForZotero() {
        assertTrue(CstCloudClientAppSupport.resolveWebDavUserAgent("zotero").contains("Zotero/8"));
    }

    @Test
    void needsClientAppBindingForDataCapsuleWebDav() {
        assertTrue(CstCloudClientAppSupport.needsClientAppBinding("https://data.cstcloud.cn/dav"));
        assertFalse(CstCloudClientAppSupport.needsClientAppBinding("https://dav.example.com"));
    }

    @Test
    void validateS3ClientAppForProvider() {
        assertThrows(IllegalArgumentException.class, () ->
                CstCloudClientAppSupport.validateS3ClientAppForProvider(S3ProviderId.DATA_CAPSULE, null));
        CstCloudClientAppSupport.validateS3ClientAppForProvider(S3ProviderId.DATA_CAPSULE, "s3browser");
        CstCloudClientAppSupport.validateS3ClientAppForProvider(S3ProviderId.CUSTOM, null);
    }

    @Test
    void validateWebDavClientAppDefaultsToZotero() {
        CstCloudClientAppSupport.validateWebDavClientApp("https://data.cstcloud.cn/dav", null);
    }
}
