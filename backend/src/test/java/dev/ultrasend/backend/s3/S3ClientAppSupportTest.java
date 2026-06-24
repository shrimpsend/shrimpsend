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
    void validateRequiresClientAppForCstCloud() {
        assertThrows(IllegalArgumentException.class, () ->
                S3ClientAppSupport.validateClientAppForEndpoint("https://s3.cstcloud.cn", null));
        S3ClientAppSupport.validateClientAppForEndpoint("https://s3.cstcloud.cn", "s3browser");
        S3ClientAppSupport.validateClientAppForEndpoint("https://s3.amazonaws.com", null);
    }
}
