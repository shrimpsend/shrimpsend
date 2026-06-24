package dev.ultrasend.backend.s3;

import dev.ultrasend.backend.dto.*;
import dev.ultrasend.backend.entity.S3Config;

import java.util.List;
import java.util.Locale;

public final class S3ProviderCatalog {

    private S3ProviderCatalog() {
    }

    public static S3ProvidersResponse buildCatalogResponse() {
        return S3ProvidersResponse.builder()
                .providers(List.of(
                        customProvider(),
                        dataCapsuleProvider(),
                        bitifulProvider(),
                        tencentCosProvider(),
                        cloudflareR2Provider()))
                .clientAppOptions(clientAppOptions())
                .tencentCosRegions(tencentCosRegions())
                .build();
    }

    public static String inferProviderId(S3Config config) {
        if (config == null) {
            return S3ProviderId.CUSTOM;
        }
        if (config.getProviderId() != null && !config.getProviderId().isBlank()) {
            String stored = S3ProviderId.normalize(config.getProviderId());
            if (!S3ProviderId.CUSTOM.equals(stored)) {
                return stored;
            }
        }
        return inferProviderIdFromEndpoint(config.getEndpoint());
    }

    public static String inferProviderIdFromEndpoint(String endpoint) {
        if (endpoint == null || endpoint.isBlank()) {
            return S3ProviderId.CUSTOM;
        }
        String lower = endpoint.toLowerCase(Locale.ROOT);
        if (lower.contains("cstcloud.cn")) {
            return S3ProviderId.DATA_CAPSULE;
        }
        if (lower.contains("s3.bitiful.net") || lower.contains("bitiful.net")) {
            return S3ProviderId.BITIFUL;
        }
        if (lower.contains("myqcloud.com") || lower.contains(".cos.")) {
            return S3ProviderId.TENCENT_COS;
        }
        if (lower.contains("r2.cloudflarestorage.com")) {
            return S3ProviderId.CLOUDFLARE_R2;
        }
        return S3ProviderId.CUSTOM;
    }

    public static String resolveDefaultRegion(String providerId) {
        return switch (S3ProviderId.normalize(providerId)) {
            case S3ProviderId.DATA_CAPSULE, S3ProviderId.CUSTOM -> "us-east-1";
            case S3ProviderId.CLOUDFLARE_R2 -> "auto";
            default -> "us-east-1";
        };
    }

    private static S3ProviderCatalogItemDto customProvider() {
        return S3ProviderCatalogItemDto.builder()
                .id(S3ProviderId.CUSTOM)
                .label("Custom / Other S3")
                .labelZh("自定义 / 其他 S3 兼容")
                .docsSection("overview")
                .defaults(S3ProviderDefaultsDto.builder()
                        .region("us-east-1")
                        .pathStyleAccessEnabled(true)
                        .endpointPlaceholder("https://s3.amazonaws.com")
                        .regionPlaceholder("us-east-1")
                        .build())
                .fields(S3ProviderFieldsDto.builder()
                        .endpoint("editable")
                        .region("editable")
                        .pathStyle("editable")
                        .clientApp("hidden")
                        .tencentRegionPicker(false)
                        .build())
                .build();
    }

    private static S3ProviderCatalogItemDto dataCapsuleProvider() {
        return S3ProviderCatalogItemDto.builder()
                .id(S3ProviderId.DATA_CAPSULE)
                .label("CSTCloud Data Capsule")
                .labelZh("中国科技云数据胶囊")
                .docsSection("data-capsule")
                .defaults(S3ProviderDefaultsDto.builder()
                        .endpoint("https://s3.cstcloud.cn")
                        .region("us-east-1")
                        .pathStyleAccessEnabled(true)
                        .build())
                .fields(S3ProviderFieldsDto.builder()
                        .endpoint("editable")
                        .region("editable")
                        .pathStyle("fixed")
                        .clientApp("required")
                        .tencentRegionPicker(false)
                        .build())
                .build();
    }

    private static S3ProviderCatalogItemDto bitifulProvider() {
        return S3ProviderCatalogItemDto.builder()
                .id(S3ProviderId.BITIFUL)
                .label("Bitiful")
                .labelZh("缤纷云")
                .docsSection("bitiful")
                .defaults(S3ProviderDefaultsDto.builder()
                        .endpoint("https://s3.bitiful.net")
                        .region("")
                        .pathStyleAccessEnabled(false)
                        .regionPlaceholder("cn-east-1")
                        .build())
                .fields(S3ProviderFieldsDto.builder()
                        .endpoint("fixed")
                        .region("editable")
                        .pathStyle("fixed")
                        .clientApp("hidden")
                        .tencentRegionPicker(false)
                        .build())
                .build();
    }

    private static S3ProviderCatalogItemDto tencentCosProvider() {
        return S3ProviderCatalogItemDto.builder()
                .id(S3ProviderId.TENCENT_COS)
                .label("Tencent COS")
                .labelZh("腾讯云 COS")
                .docsSection("tencent-cos")
                .defaults(S3ProviderDefaultsDto.builder()
                        .pathStyleAccessEnabled(false)
                        .build())
                .fields(S3ProviderFieldsDto.builder()
                        .endpoint("fixed")
                        .region("fixed")
                        .pathStyle("fixed")
                        .clientApp("hidden")
                        .tencentRegionPicker(true)
                        .build())
                .build();
    }

    private static S3ProviderCatalogItemDto cloudflareR2Provider() {
        return S3ProviderCatalogItemDto.builder()
                .id(S3ProviderId.CLOUDFLARE_R2)
                .label("Cloudflare R2")
                .labelZh("Cloudflare R2")
                .docsSection("cloudflare-r2")
                .defaults(S3ProviderDefaultsDto.builder()
                        .endpoint("")
                        .region("auto")
                        .pathStyleAccessEnabled(true)
                        .endpointPlaceholder("https://<accountid>.r2.cloudflarestorage.com")
                        .build())
                .fields(S3ProviderFieldsDto.builder()
                        .endpoint("editable")
                        .region("readonly")
                        .pathStyle("fixed")
                        .clientApp("hidden")
                        .tencentRegionPicker(false)
                        .build())
                .build();
    }

    private static List<S3ClientAppOptionDto> clientAppOptions() {
        return List.of(
                option("s3drive", "S3Drive"),
                option("s3browser", "S3Browser"),
                option("rclone", "Rclone"),
                option("obsidian", "Obsidian"),
                option("cherry_studio", "Cherry Studio"));
    }

    private static List<S3TencentCosRegionDto> tencentCosRegions() {
        return List.of(
                cosRegion("ap-guangzhou", "广州", "ap-guangzhou", "https://cos.ap-guangzhou.myqcloud.com"),
                cosRegion("ap-shanghai", "上海", "ap-shanghai", "https://cos.ap-shanghai.myqcloud.com"),
                cosRegion("ap-beijing", "北京", "ap-beijing", "https://cos.ap-beijing.myqcloud.com"),
                cosRegion("ap-nanjing", "南京", "ap-nanjing", "https://cos.ap-nanjing.myqcloud.com"),
                cosRegion("ap-chengdu", "成都", "ap-chengdu", "https://cos.ap-chengdu.myqcloud.com"),
                cosRegion("ap-chongqing", "重庆", "ap-chongqing", "https://cos.ap-chongqing.myqcloud.com"),
                cosRegion("ap-hongkong", "香港", "ap-hongkong", "https://cos.ap-hongkong.myqcloud.com"),
                cosRegion("ap-singapore", "新加坡", "ap-singapore", "https://cos.ap-singapore.myqcloud.com"));
    }

    private static S3ClientAppOptionDto option(String id, String label) {
        return S3ClientAppOptionDto.builder().id(id).label(label).build();
    }

    private static S3TencentCosRegionDto cosRegion(String id, String label, String region, String endpoint) {
        return S3TencentCosRegionDto.builder()
                .id(id)
                .label(label)
                .region(region)
                .endpoint(endpoint)
                .build();
    }
}
