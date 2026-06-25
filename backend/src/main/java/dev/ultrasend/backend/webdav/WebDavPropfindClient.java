package dev.ultrasend.backend.webdav;

import dev.ultrasend.backend.cstcloud.CstCloudClientAppSupport;
import dev.ultrasend.backend.tls.CstCloudTlsSupport;
import lombok.extern.slf4j.Slf4j;

import javax.net.ssl.SSLContext;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Base64;

/**
 * Minimal WebDAV PROPFIND client for connectivity tests.
 */
@Slf4j
public final class WebDavPropfindClient {

    private static final String PROPFIND_BODY = """
            <?xml version="1.0" encoding="utf-8" ?>
            <d:propfind xmlns:d="DAV:">
              <d:prop>
                <d:displayname/>
              </d:prop>
            </d:propfind>
            """;

    private WebDavPropfindClient() {
    }

    public static void propfindDepth0(
            String baseUrl,
            String rootPath,
            String username,
            String password,
            String userAgent)
            throws Exception {
        String url = buildListUrl(baseUrl, rootPath);
        String auth = Base64.getEncoder().encodeToString(
                (username + ":" + password).getBytes(StandardCharsets.UTF_8));

        HttpClient.Builder clientBuilder = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(15))
                .followRedirects(HttpClient.Redirect.NORMAL);
        SSLContext sslContext = CstCloudTlsSupport.sslContextFor(baseUrl);
        if (sslContext != null) {
            clientBuilder.sslContext(sslContext);
        }
        HttpClient client = clientBuilder.build();

        HttpRequest.Builder requestBuilder = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .timeout(Duration.ofSeconds(30))
                .header("Authorization", "Basic " + auth)
                .header("Depth", "0")
                .header("Content-Type", "application/xml; charset=utf-8");
        if (userAgent != null && !userAgent.isBlank()) {
            requestBuilder.header("User-Agent", userAgent);
        }
        HttpRequest request = requestBuilder
                .method("PROPFIND", HttpRequest.BodyPublishers.ofString(PROPFIND_BODY))
                .build();

        HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());
        int code = response.statusCode();
        if (code >= 200 && code < 300) {
            return;
        }
        if (code == 401 || code == 403) {
            if (CstCloudClientAppSupport.needsClientAppBinding(baseUrl)) {
                throw new IllegalArgumentException(
                        "Authentication failed (HTTP " + code
                                + "). Select the client application that matches your Data Capsule WebDAV credential.");
            }
            throw new IllegalArgumentException("Authentication failed (HTTP " + code + ")");
        }
        throw new IllegalArgumentException("WebDAV server returned HTTP " + code);
    }

    public static String buildListUrl(String baseUrl, String rootPath) {
        String base = normalizeBaseUrl(baseUrl);
        String path = normalizeRootPath(rootPath);
        if (path.equals("/")) {
            return base.endsWith("/") ? base : base + "/";
        }
        String combined = base + path;
        return combined.endsWith("/") ? combined : combined + "/";
    }

    public static String normalizeBaseUrl(String baseUrl) {
        if (baseUrl == null || baseUrl.isBlank()) {
            throw new IllegalArgumentException("baseUrl is required");
        }
        String trimmed = baseUrl.trim();
        if (!trimmed.startsWith("http://") && !trimmed.startsWith("https://")) {
            throw new IllegalArgumentException("baseUrl must start with http:// or https://");
        }
        URI uri = URI.create(trimmed);
        if (uri.getUserInfo() != null && !uri.getUserInfo().isBlank()) {
            throw new IllegalArgumentException("baseUrl must not contain embedded credentials");
        }
        if (uri.getQuery() != null && !uri.getQuery().isBlank()) {
            throw new IllegalArgumentException("baseUrl must not contain query parameters");
        }
        while (trimmed.endsWith("/") && trimmed.length() > "https://x".length()) {
            trimmed = trimmed.substring(0, trimmed.length() - 1);
        }
        return trimmed;
    }

    public static String normalizeRootPath(String rootPath) {
        if (rootPath == null || rootPath.isBlank()) {
            return "/";
        }
        String p = rootPath.trim();
        if (!p.startsWith("/")) {
            p = "/" + p;
        }
        while (p.length() > 1 && p.endsWith("/")) {
            p = p.substring(0, p.length() - 1);
        }
        return p;
    }

    @SuppressWarnings("unused")
    static String encodePathSegment(String segment) {
        return URLEncoder.encode(segment, StandardCharsets.UTF_8).replace("+", "%20");
    }
}
