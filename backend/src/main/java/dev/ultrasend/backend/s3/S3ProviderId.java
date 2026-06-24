package dev.ultrasend.backend.s3;

import java.util.Locale;

public final class S3ProviderId {

    public static final String CUSTOM = "custom";
    public static final String DATA_CAPSULE = "data_capsule";
    public static final String BITIFUL = "bitiful";
    public static final String TENCENT_COS = "tencent_cos";
    public static final String CLOUDFLARE_R2 = "cloudflare_r2";

    private S3ProviderId() {
    }

    public static String normalize(String providerId) {
        if (providerId == null || providerId.isBlank()) {
            return CUSTOM;
        }
        String id = providerId.trim().toLowerCase(Locale.ROOT);
        return switch (id) {
            case DATA_CAPSULE, BITIFUL, TENCENT_COS, CLOUDFLARE_R2 -> id;
            default -> CUSTOM;
        };
    }

    public static boolean isKnown(String providerId) {
        String id = normalize(providerId);
        return !CUSTOM.equals(id) || CUSTOM.equals(providerId == null ? CUSTOM : providerId.trim().toLowerCase(Locale.ROOT));
    }
}
