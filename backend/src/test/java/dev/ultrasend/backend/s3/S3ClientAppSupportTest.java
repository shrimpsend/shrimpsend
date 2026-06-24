package dev.ultrasend.backend.s3;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class S3ClientAppSupportTest {

    @Test
    void resolveUserAgentForKnownApps() {
        assertEquals("S3 Browser", S3ClientAppSupport.resolveUserAgent("s3browser"));
        assertEquals("rclone/v1.67.0", S3ClientAppSupport.resolveUserAgent("rclone"));
    }

    @Test
    void validateRequiresClientAppForDataCapsuleProvider() {
        assertThrows(IllegalArgumentException.class, () ->
                S3ClientAppSupport.validateClientAppForProvider(S3ProviderId.DATA_CAPSULE, null));
        S3ClientAppSupport.validateClientAppForProvider(S3ProviderId.DATA_CAPSULE, "s3browser");
        S3ClientAppSupport.validateClientAppForProvider(S3ProviderId.CUSTOM, null);
    }
}
