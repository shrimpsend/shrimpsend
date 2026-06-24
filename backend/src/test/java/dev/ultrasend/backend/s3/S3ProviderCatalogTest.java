package dev.ultrasend.backend.s3;

import dev.ultrasend.backend.entity.S3Config;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

class S3ProviderCatalogTest {

    @Test
    void inferProviderIdFromEndpoint() {
        assertEquals(S3ProviderId.DATA_CAPSULE,
                S3ProviderCatalog.inferProviderIdFromEndpoint("https://s3.cstcloud.cn"));
        assertEquals(S3ProviderId.BITIFUL,
                S3ProviderCatalog.inferProviderIdFromEndpoint("https://s3.bitiful.net"));
        assertEquals(S3ProviderId.TENCENT_COS,
                S3ProviderCatalog.inferProviderIdFromEndpoint("https://cos.ap-guangzhou.myqcloud.com"));
        assertEquals(S3ProviderId.CLOUDFLARE_R2,
                S3ProviderCatalog.inferProviderIdFromEndpoint("https://abc.r2.cloudflarestorage.com"));
        assertEquals(S3ProviderId.CUSTOM,
                S3ProviderCatalog.inferProviderIdFromEndpoint("https://s3.amazonaws.com"));
    }

    @Test
    void inferProviderIdPrefersStoredValue() {
        S3Config config = S3Config.builder()
                .providerId(S3ProviderId.BITIFUL)
                .endpoint("https://s3.cstcloud.cn")
                .build();
        assertEquals(S3ProviderId.BITIFUL, S3ProviderCatalog.inferProviderId(config));
    }

    @Test
    void inferProviderIdFromEndpointWhenCustomStored() {
        S3Config config = S3Config.builder()
                .providerId(S3ProviderId.CUSTOM)
                .endpoint("https://s3.cstcloud.cn")
                .build();
        assertEquals(S3ProviderId.DATA_CAPSULE, S3ProviderCatalog.inferProviderId(config));
    }

    @Test
    void resolveDefaultRegion() {
        assertEquals("us-east-1", S3ProviderCatalog.resolveDefaultRegion(S3ProviderId.CUSTOM));
        assertEquals("auto", S3ProviderCatalog.resolveDefaultRegion(S3ProviderId.CLOUDFLARE_R2));
    }
}
