package dev.ultrasend.backend.cstcloud;

import dev.ultrasend.backend.s3.S3ProviderId;

import java.util.Locale;
import java.util.Map;

/**
 * Maps CSTCloud Data Capsule "client application" bindings to HTTP User-Agent strings.
 * S3 AccessKeys and WebDAV credentials must be created for a specific app in the console;
 * the gateway rejects requests whose User-Agent does not match the binding.
 */
public final class CstCloudClientAppSupport {

    public static final String DEFAULT_S3_USER_AGENT = "ShrimpSend/1.0 S3Compat";

    private static final Map<String, String> S3_USER_AGENTS = Map.of(
            "s3drive", "S3Drive",
            "s3browser", "S3 Browser",
            "rclone", "rclone/v1.67.0",
            "obsidian", "obsidian",
            "cherry_studio", "Cherry Studio");

    /** Data Capsule WebDAV only supports Zotero 8+ credentials. */
    private static final String WEBDAV_CLIENT_APP = "zotero";

    /** Zotero 8+ UA used by Data Capsule WebDAV. */
    private static final String ZOTERO_8_USER_AGENT =
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0 Zotero/8.0.3";

    private CstCloudClientAppSupport() {
    }

    public static boolean needsClientAppBinding(String url) {
        if (url == null || url.isBlank()) {
            return false;
        }
        try {
            String host = java.net.URI.create(url.trim()).getHost();
            return host != null && host.toLowerCase(Locale.ROOT).endsWith("cstcloud.cn");
        } catch (Exception ignored) {
            return false;
        }
    }

    public static boolean isKnownS3App(String clientApp) {
        if (clientApp == null || clientApp.isBlank()) {
            return false;
        }
        return S3_USER_AGENTS.containsKey(clientApp.trim().toLowerCase(Locale.ROOT));
    }

    public static boolean isKnownWebDavApp(String clientApp) {
        if (clientApp == null || clientApp.isBlank()) {
            return true;
        }
        return WEBDAV_CLIENT_APP.equals(clientApp.trim().toLowerCase(Locale.ROOT));
    }

    public static String defaultWebDavClientApp() {
        return WEBDAV_CLIENT_APP;
    }

    public static String resolveS3UserAgent(String clientApp) {
        if (clientApp == null || clientApp.isBlank()) {
            return DEFAULT_S3_USER_AGENT;
        }
        return S3_USER_AGENTS.getOrDefault(clientApp.trim().toLowerCase(Locale.ROOT), DEFAULT_S3_USER_AGENT);
    }

    public static String resolveWebDavUserAgent(String clientApp) {
        return ZOTERO_8_USER_AGENT;
    }

    public static void validateS3ClientAppForProvider(String providerId, String clientApp) {
        if (!S3ProviderId.DATA_CAPSULE.equals(S3ProviderId.normalize(providerId))) {
            return;
        }
        if (!isKnownS3App(clientApp)) {
            throw new IllegalArgumentException(
                    "中国科技云数据胶囊需选择客户端应用（须与控制台创建 AccessKey 时绑定的应用一致）");
        }
    }

    public static void validateWebDavClientApp(String baseUrl, String clientApp) {
        if (!needsClientAppBinding(baseUrl)) {
            return;
        }
        String normalized = clientApp == null || clientApp.isBlank()
                ? WEBDAV_CLIENT_APP
                : clientApp.trim().toLowerCase(Locale.ROOT);
        if (!WEBDAV_CLIENT_APP.equals(normalized)) {
            throw new IllegalArgumentException(
                    "中国科技云数据胶囊 WebDAV 仅支持 Zotero（8 及以上）客户端应用");
        }
    }
}
