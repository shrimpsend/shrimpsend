package dev.ultrasend.backend.s3;

import java.util.Locale;
import java.util.Map;

/**
 * Maps CSTCloud Data Capsule "client application" bindings to HTTP User-Agent strings.
 * AccessKeys must be created for a specific app in the Data Capsule console; the gateway
 * rejects requests whose User-Agent does not match the binding.
 */
public final class S3ClientAppSupport {

    public static final String DEFAULT_USER_AGENT = "ShrimpSend/1.0 S3Compat";

    private static final Map<String, String> USER_AGENTS = Map.of(
            "s3drive", "S3Drive",
            "s3browser", "S3 Browser",
            "rclone", "rclone/v1.67.0",
            "obsidian", "obsidian",
            "cherry_studio", "Cherry Studio");

    private S3ClientAppSupport() {
    }

    public static boolean isKnownApp(String clientApp) {
        if (clientApp == null || clientApp.isBlank()) {
            return false;
        }
        return USER_AGENTS.containsKey(clientApp.trim().toLowerCase(Locale.ROOT));
    }

    public static boolean requiresClientApp(String endpoint) {
        if (endpoint == null || endpoint.isBlank()) {
            return false;
        }
        return endpoint.toLowerCase(Locale.ROOT).contains("cstcloud.cn");
    }

    public static String resolveUserAgent(String clientApp) {
        if (clientApp == null || clientApp.isBlank()) {
            return DEFAULT_USER_AGENT;
        }
        return USER_AGENTS.getOrDefault(clientApp.trim().toLowerCase(Locale.ROOT), DEFAULT_USER_AGENT);
    }

    public static void validateClientAppForEndpoint(String endpoint, String clientApp) {
        if (!requiresClientApp(endpoint)) {
            return;
        }
        if (!isKnownApp(clientApp)) {
            throw new IllegalArgumentException(
                    "中国科技云数据胶囊需选择客户端应用（须与控制台创建 AccessKey 时绑定的应用一致）");
        }
    }
}
