package dev.ultrasend.backend.service;

import dev.ultrasend.backend.dto.*;
import dev.ultrasend.backend.entity.S3Config;
import dev.ultrasend.backend.entity.User;
import dev.ultrasend.backend.repository.S3ConfigRepository;
import dev.ultrasend.backend.repository.UserRepository;
import dev.ultrasend.backend.cstcloud.CstCloudClientAppSupport;
import dev.ultrasend.backend.s3.S3ProviderCatalog;
import dev.ultrasend.backend.s3.S3ProviderId;
import dev.ultrasend.backend.tls.CstCloudTlsSupport;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.core.checksums.RequestChecksumCalculation;
import software.amazon.awssdk.core.checksums.ResponseChecksumValidation;
import software.amazon.awssdk.core.client.config.ClientOverrideConfiguration;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.model.*;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.*;
import software.amazon.awssdk.http.urlconnection.UrlConnectionHttpClient;

import javax.net.ssl.TrustManager;

import java.net.URI;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.time.Duration;

@Service
@RequiredArgsConstructor
@Slf4j
public class S3Service {

    /** User-Agent for BYO S3 requests; some providers (e.g. CSTCloud Data Capsule) validate client binding via UA. */
    static final String BYO_S3_USER_AGENT = "ShrimpSend/1.0 S3Compat";

    /** Legacy BYO object key prefix used by pre-refactor Web direct upload. */
    static final String LEGACY_UPLOAD_PREFIX = "uploads/";

    private final S3ConfigRepository s3ConfigRepository;
    private final UserRepository userRepository;
    private final HostedS3Service hostedS3Service;
    private final UserDataEncryptionService userDataEncryption;

    @Value("${app.public-web-base-url:http://localhost:3000}")
    private String publicWebBaseUrl;

    @Value("${app.s3-docs-path:/zh/docs/s3/overview}")
    private String s3DocsPath;

    private String buildS3DocumentationUrl() {
        String base = publicWebBaseUrl == null ? "" : publicWebBaseUrl.trim();
        if (base.isEmpty()) {
            return "";
        }
        String path = s3DocsPath == null ? "/zh/docs/s3/overview" : s3DocsPath.trim();
        if (path.isEmpty()) {
            path = "/zh/docs/s3/overview";
        }
        if (!path.startsWith("/")) {
            path = "/" + path;
        }
        while (base.endsWith("/")) {
            base = base.substring(0, base.length() - 1);
        }
        return base + path;
    }

    private String buildProviderDocumentationUrl(String docsSection) {
        if (docsSection == null || docsSection.isBlank() || "overview".equals(docsSection)) {
            return buildS3DocumentationUrl();
        }
        String base = publicWebBaseUrl == null ? "" : publicWebBaseUrl.trim();
        if (base.isEmpty()) {
            return "";
        }
        String path = s3DocsPath == null ? "/zh/docs/s3/overview" : s3DocsPath.trim();
        if (path.isEmpty()) {
            path = "/zh/docs/s3/overview";
        }
        if (path.endsWith("/overview")) {
            path = path.substring(0, path.length() - "/overview".length()) + "/" + docsSection;
        } else if (!path.endsWith("/" + docsSection)) {
            if (!path.endsWith("/")) {
                path = path + "/";
            }
            path = path + docsSection;
        }
        if (!path.startsWith("/")) {
            path = "/" + path;
        }
        while (base.endsWith("/")) {
            base = base.substring(0, base.length() - 1);
        }
        return base + path;
    }

    public S3ProvidersResponse getProviders() {
        return S3ProviderCatalog.buildCatalogResponse();
    }

    @Transactional
    public void saveConfig(Long userId, S3ConfigRequest req) {
        String providerId = resolveProviderIdForSave(req);
        CstCloudClientAppSupport.validateS3ClientAppForProvider(providerId, req.getClientApp());
        User user = userRepository.findById(userId).orElseThrow();
        S3Config config = s3ConfigRepository.findByUserId(userId)
                .orElse(S3Config.builder().user(user).build());
        config.setEndpoint(req.getEndpoint());
        config.setRegion(resolveRegionForSave(providerId, req.getRegion()));
        config.setBucket(req.getBucket());
        config.setAccessKeyId(req.getAccessKeyId());
        if (req.getSecretAccessKey() != null && !req.getSecretAccessKey().isBlank()) {
            config.setSecretAccessKey(userDataEncryption.encryptForUser(userId, req.getSecretAccessKey()));
        }
        boolean pathStyle = req.getPathStyleAccessEnabled() != null ? req.getPathStyleAccessEnabled() : true;
        config.setPathStyleAccessEnabled(pathStyle);
        warnIfPathStyleMismatch(providerId, pathStyle);
        config.setClientApp(normalizeClientApp(req.getClientApp()));
        config.setProviderId(providerId);
        // 用户主动保存 BYO 即视为「使用自建 S3」
        config.setPrefersHosted(false);
        s3ConfigRepository.save(config);
        log.info("s3 saveConfig saved userId={} bucket={} providerId={} clientApp={}", userId, config.getBucket(),
                providerId, config.getClientApp());
    }

    private static String resolveProviderIdForSave(S3ConfigRequest req) {
        if (req.getProviderId() != null && !req.getProviderId().isBlank()) {
            return S3ProviderId.normalize(req.getProviderId());
        }
        return S3ProviderCatalog.inferProviderIdFromEndpoint(req.getEndpoint());
    }

    private static String resolveRegionForSave(String providerId, String region) {
        if (region != null && !region.isBlank()) {
            return region.trim();
        }
        return S3ProviderCatalog.resolveDefaultRegion(providerId);
    }

    private static void warnIfPathStyleMismatch(String providerId, boolean pathStyle) {
        if (!pathStyle) {
            return;
        }
        String id = S3ProviderId.normalize(providerId);
        if (S3ProviderId.BITIFUL.equals(id) || S3ProviderId.TENCENT_COS.equals(id)) {
            log.warn("s3 saveConfig pathStyle=true for provider={} (usually should be false)", id);
        }
    }

    private static String normalizeClientApp(String clientApp) {
        if (clientApp == null || clientApp.isBlank()) {
            return null;
        }
        return clientApp.trim().toLowerCase();
    }

    public boolean hasConfig(Long userId) {
        return s3ConfigRepository.findByUserId(userId).isPresent();
    }

    public S3ConfigResponse getConfig(Long userId) {
        boolean hostedAvailable = hostedS3Service.isActive();
        S3ConfigResponse res = s3ConfigRepository.findByUserId(userId)
                .map(c -> {
                    boolean prefersHosted = Boolean.TRUE.equals(c.getPrefersHosted());
                    boolean useHosted = prefersHosted && hostedAvailable;
                    if (useHosted) {
                        // BYO 已保存但用户当前偏好托管：返回 HOSTED，但保留 customSaved=true
                        return S3ConfigResponse.builder()
                                .mode(S3StorageMode.HOSTED)
                                .configured(true)
                                .hostedAvailable(true)
                                .customSaved(true)
                                .build();
                    }
                    return S3ConfigResponse.builder()
                            .mode(S3StorageMode.CUSTOM)
                            .configured(true)
                            .hostedAvailable(hostedAvailable)
                            .customSaved(true)
                            .endpoint(c.getEndpoint())
                            .region(c.getRegion())
                            .bucket(c.getBucket())
                            .accessKeyId(c.getAccessKeyId())
                            .pathStyleAccessEnabled(resolvePathStyle(c.getPathStyleAccessEnabled()))
                            .clientApp(c.getClientApp())
                            .userAgent(resolveByoUserAgent(c))
                            .providerId(S3ProviderCatalog.inferProviderId(c))
                            .providerDocsUrl(buildProviderDocsUrlForConfig(c))
                            .build();
                })
                .orElseGet(() -> {
                    S3StorageMode mode = hostedAvailable ? S3StorageMode.HOSTED : S3StorageMode.DISABLED;
                    return S3ConfigResponse.builder()
                            .mode(mode)
                            .configured(mode != S3StorageMode.DISABLED)
                            .hostedAvailable(hostedAvailable)
                            .customSaved(false)
                            .build();
                });
        res.setDocumentationUrl(buildS3DocumentationUrl());
        log.debug("s3 getConfig userId={} mode={} hostedAvailable={} customSaved={}",
                userId, res.getMode(), res.isHostedAvailable(), res.isCustomSaved());
        return res;
    }

    @Transactional
    public void deleteConfig(Long userId) {
        s3ConfigRepository.findByUserId(userId).ifPresent(s3ConfigRepository::delete);
        log.info("s3 deleteConfig userId={}", userId);
    }

    /**
     * 切换到「使用平台内置 S3」但保留已保存的自建凭证。
     * 仅当当前部署提供 hosted 桶时允许。
     */
    @Transactional
    public void preferHosted(Long userId) {
        if (!hostedS3Service.isActive()) {
            throw new IllegalArgumentException("Hosted storage not available");
        }
        s3ConfigRepository.findByUserId(userId).ifPresentOrElse(c -> {
            c.setPrefersHosted(true);
            s3ConfigRepository.save(c);
            log.info("s3 preferHosted userId={} (BYO retained)", userId);
        }, () -> log.info("s3 preferHosted userId={} (no BYO present, no-op)", userId));
    }

    /**
     * 切换到「使用已保存的自建 S3」。要求用户先前保存过 BYO 凭证。
     */
    @Transactional
    public void preferCustom(Long userId) {
        S3Config config = s3ConfigRepository.findByUserId(userId)
                .orElseThrow(() -> new IllegalArgumentException("No saved custom S3 config"));
        config.setPrefersHosted(false);
        s3ConfigRepository.save(config);
        log.info("s3 preferCustom userId={} bucket={}", userId, config.getBucket());
    }

    /**
     * 为 CUSTOM 自建 S3 签发 HeadBucket 预签名 URL，供客户端在本机网络探测。
     * 不在服务端执行 HeadBucket；HOSTED 或未配置 BYO 时拒绝。
     */
    public S3TestUrlResponse presignTestUrl(Long userId) {
        var byo = s3ConfigRepository.findByUserId(userId);
        boolean useHosted = byo.map(c -> Boolean.TRUE.equals(c.getPrefersHosted()))
                .orElse(true) && hostedS3Service.isActive();
        if (useHosted) {
            log.warn("s3 presignTestUrl rejected hosted mode userId={}", userId);
            throw new IllegalArgumentException("内置 S3 无需测试连接");
        }
        if (byo.isEmpty()) {
            log.warn("s3 presignTestUrl not configured userId={}", userId);
            throw new IllegalArgumentException("S3 未配置");
        }
        S3Config config = byo.get();
        String serverProbe = "ok";
        String serverError = null;
        try (S3Client client = buildS3Client(userId, config)) {
            client.headBucket(HeadBucketRequest.builder().bucket(config.getBucket()).build());
            log.info("s3 serverProbe ok userId={} bucket={}", userId, config.getBucket());
        } catch (S3Exception e) {
            serverProbe = "failed";
            serverError = formatS3Error(e);
            log.warn("s3 serverProbe failed userId={} bucket={} httpStatus={} error={}",
                    userId, config.getBucket(), e.statusCode(), serverError);
        } catch (Exception e) {
            serverError = e.getMessage() != null ? e.getMessage() : e.getClass().getSimpleName();
            if (CstCloudTlsSupport.isSslProbeError(serverError, e)) {
                serverProbe = "ssl_failed";
                log.warn("s3 serverProbe ssl_failed userId={} bucket={} error={}", userId, config.getBucket(),
                        serverError);
            } else {
                serverProbe = "failed";
                log.warn("s3 serverProbe failed userId={} bucket={} error={}", userId, config.getBucket(), serverError,
                        e);
            }
        }

        try (PresignerSession session = openPresigner(userId, config)) {
            HeadBucketRequest headReq = HeadBucketRequest.builder()
                    .bucket(config.getBucket())
                    .build();
            HeadBucketPresignRequest presignReq = HeadBucketPresignRequest.builder()
                    .signatureDuration(Duration.ofSeconds(60))
                    .headBucketRequest(headReq)
                    .build();
            PresignedHeadBucketRequest presigned = session.presigner().presignHeadBucket(presignReq);
            String url = presigned.url().toString();
            logPresignTestUrlSummary(userId, config, url);
            return S3TestUrlResponse.builder()
                    .url(url)
                    .serverProbe(serverProbe)
                    .serverError(serverError)
                    .build();
        } catch (IllegalArgumentException e) {
            throw e;
        } catch (Exception e) {
            log.warn("s3 presignTestUrl failed userId={}", userId, e);
            throw new IllegalArgumentException("S3 连接失败: "
                    + (e.getMessage() != null ? e.getMessage() : e.getClass().getSimpleName()));
        }
    }

    private static String formatS3Error(S3Exception e) {
        String detail = null;
        if (e.awsErrorDetails() != null) {
            String code = e.awsErrorDetails().errorCode();
            String message = e.awsErrorDetails().errorMessage();
            if (code != null && message != null) {
                detail = code + ": " + message;
            } else if (code != null) {
                detail = code;
            } else if (message != null) {
                detail = message;
            }
        }
        if (detail == null || detail.isBlank()) {
            detail = e.getMessage() != null ? e.getMessage() : e.getClass().getSimpleName();
        }
        if (e.statusCode() > 0) {
            return "HTTP " + e.statusCode() + (detail.isBlank() ? "" : " " + detail);
        }
        return detail;
    }

    private void logPresignTestUrlSummary(Long userId, S3Config config, String presignedUrl) {
        String signedHeaders = presignQueryParam(presignedUrl, "X-Amz-SignedHeaders");
        String credentialScope = presignCredentialScope(presignedUrl);
        log.info("s3 presignTestUrl ok userId={} endpoint={} region={} bucket={} pathStyle={} "
                        + "signedHeaders={} credentialScope={}",
                userId,
                config.getEndpoint(),
                config.getRegion() != null ? config.getRegion() : "cn-east-1",
                config.getBucket(),
                resolvePathStyle(config.getPathStyleAccessEnabled()),
                signedHeaders,
                credentialScope);
    }

    private static String presignQueryParam(String url, String key) {
        try {
            URI uri = URI.create(url);
            String query = uri.getRawQuery();
            if (query == null || query.isBlank()) {
                return null;
            }
            for (String part : query.split("&")) {
                int eq = part.indexOf('=');
                if (eq <= 0) {
                    continue;
                }
                String name = URLDecoder.decode(part.substring(0, eq), StandardCharsets.UTF_8);
                if (key.equals(name)) {
                    return URLDecoder.decode(part.substring(eq + 1), StandardCharsets.UTF_8);
                }
            }
        } catch (Exception ignored) {
            // best-effort logging helper
        }
        return null;
    }

    private static String presignCredentialScope(String url) {
        String credential = presignQueryParam(url, "X-Amz-Credential");
        if (credential == null) {
            return null;
        }
        int slash = credential.indexOf('/');
        if (slash < 0 || slash == credential.length() - 1) {
            return credential;
        }
        return credential.substring(slash + 1);
    }

    public PresignUploadResponse presignUpload(Long userId, String fileName, String contentType, Long contentLength) {
        if (hostedS3Service.useHostedForUser(userId)) {
            long len = contentLength != null ? contentLength : 0L;
            return hostedS3Service.presignUpload(userId, fileName, contentType, len);
        }
        S3Config config = s3ConfigRepository.findByUserId(userId)
                .orElseThrow(() -> new IllegalArgumentException("S3 not configured"));
        String key = generateByoUploadKey(fileName);
        log.debug("s3 presignUpload userId={} key={}", userId, key);

        try (PresignerSession session = openPresigner(userId, config)) {
            // Do not sign Content-Type: legacy Web presign only signed host, and browser may send
            // a Content-Type that differs from the presign default.
            PutObjectRequest putRequest = PutObjectRequest.builder()
                    .bucket(config.getBucket())
                    .key(key)
                    .build();
            PutObjectPresignRequest presignRequest = PutObjectPresignRequest.builder()
                    .signatureDuration(Duration.ofHours(1))
                    .putObjectRequest(putRequest)
                    .build();
            PresignedPutObjectRequest presigned = session.presigner().presignPutObject(presignRequest);
            String uploadUrl = presigned.url().toString();
            return PresignUploadResponse.builder()
                    .uploadUrl(uploadUrl)
                    .key(key)
                    .build();
        }
    }

    public String presignDownload(Long userId, String key) {
        if (hostedS3Service.useHostedForUser(userId)) {
            return hostedS3Service.presignDownload(userId, key);
        }
        S3Config config = s3ConfigRepository.findByUserId(userId)
                .orElseThrow(() -> new IllegalArgumentException("S3 not configured"));
        validateKeyOwnership(userId, key);
        log.debug("s3 presignDownload userId={} key={}", userId, key);
        try (PresignerSession session = openPresigner(userId, config)) {
            GetObjectRequest getRequest = GetObjectRequest.builder()
                    .bucket(config.getBucket())
                    .key(key)
                    .build();
            GetObjectPresignRequest presignRequest = GetObjectPresignRequest.builder()
                    .signatureDuration(Duration.ofHours(1))
                    .getObjectRequest(getRequest)
                    .build();
            var presigned = session.presigner().presignGetObject(presignRequest);
            return presigned.url().toString();
        }
    }

    // ── Multipart Upload ───────────────────────────────────────────────

    public MultipartInitiateResponse initiateMultipartUpload(Long userId, String fileName, String contentType,
                                                             Long totalSize) {
        if (hostedS3Service.useHostedForUser(userId)) {
            long sz = totalSize != null ? totalSize : 0L;
            return hostedS3Service.initiateMultipart(userId, fileName, contentType, sz);
        }
        S3Config config = s3ConfigRepository.findByUserId(userId)
                .orElseThrow(() -> new IllegalArgumentException("S3 not configured"));
        String key = generateByoUploadKey(fileName);
        log.info("s3 initiateMultipart userId={} key={}", userId, key);

        try (S3Client client = buildS3Client(userId, config)) {
            CreateMultipartUploadRequest req = CreateMultipartUploadRequest.builder()
                    .bucket(config.getBucket())
                    .key(key)
                    .contentType(contentType != null ? contentType : "application/octet-stream")
                    .build();
            CreateMultipartUploadResponse resp = client.createMultipartUpload(req);
            return MultipartInitiateResponse.builder()
                    .uploadId(resp.uploadId())
                    .key(key)
                    .build();
        }
    }

    public String presignUploadPart(Long userId, String uploadId, String key, int partNumber) {
        if (hostedS3Service.useHostedForUser(userId)) {
            return hostedS3Service.presignUploadPart(userId, uploadId, key, partNumber);
        }
        S3Config config = s3ConfigRepository.findByUserId(userId)
                .orElseThrow(() -> new IllegalArgumentException("S3 not configured"));
        validateKeyOwnership(userId, key);
        log.debug("s3 presignPart userId={} part={} key={}", userId, partNumber, key);

        try (PresignerSession session = openPresigner(userId, config)) {
            UploadPartRequest partReq = UploadPartRequest.builder()
                    .bucket(config.getBucket())
                    .key(key)
                    .uploadId(uploadId)
                    .partNumber(partNumber)
                    .build();
            UploadPartPresignRequest presignReq = UploadPartPresignRequest.builder()
                    .signatureDuration(Duration.ofHours(1))
                    .uploadPartRequest(partReq)
                    .build();
            PresignedUploadPartRequest presigned = session.presigner().presignUploadPart(presignReq);
            return presigned.url().toString();
        }
    }

    public void completeMultipartUpload(Long userId, String uploadId, String key,
                                        java.util.List<MultipartCompleteRequest.PartInfo> parts) {
        if (hostedS3Service.useHostedForUser(userId)) {
            hostedS3Service.completeMultipart(userId, uploadId, key, parts);
            return;
        }
        S3Config config = s3ConfigRepository.findByUserId(userId)
                .orElseThrow(() -> new IllegalArgumentException("S3 not configured"));
        validateKeyOwnership(userId, key);
        log.info("s3 completeMultipart userId={} key={} parts={}", userId, key, parts.size());

        java.util.List<CompletedPart> completedParts = parts.stream()
                .map(p -> CompletedPart.builder()
                        .partNumber(p.getPartNumber())
                        .eTag(p.getETag())
                        .build())
                .toList();

        try (S3Client client = buildS3Client(userId, config)) {
            CompleteMultipartUploadRequest req = CompleteMultipartUploadRequest.builder()
                    .bucket(config.getBucket())
                    .key(key)
                    .uploadId(uploadId)
                    .multipartUpload(CompletedMultipartUpload.builder()
                            .parts(completedParts)
                            .build())
                    .build();
            client.completeMultipartUpload(req);
        }
    }

    public void abortMultipartUpload(Long userId, String uploadId, String key) {
        if (hostedS3Service.useHostedForUser(userId)) {
            hostedS3Service.abortMultipart(userId, uploadId, key);
            return;
        }
        S3Config config = s3ConfigRepository.findByUserId(userId)
                .orElseThrow(() -> new IllegalArgumentException("S3 not configured"));
        validateKeyOwnership(userId, key);
        log.info("s3 abortMultipart userId={} key={}", userId, key);

        try (S3Client client = buildS3Client(userId, config)) {
            AbortMultipartUploadRequest req = AbortMultipartUploadRequest.builder()
                    .bucket(config.getBucket())
                    .key(key)
                    .uploadId(uploadId)
                    .build();
            client.abortMultipartUpload(req);
        }
    }

    // ── Helpers ────────────────────────────────────────────────────────

    void validateKeyOwnership(Long userId, String key) {
        if (key == null || key.isBlank() || key.startsWith("/") || key.contains("..")) {
            throw new IllegalArgumentException("Invalid key");
        }
        if (key.startsWith("ultrasend/" + userId + "/")) {
            return;
        }
        if (key.startsWith(LEGACY_UPLOAD_PREFIX)) {
            return;
        }
        throw new IllegalArgumentException("Invalid key");
    }

    /**
     * Legacy BYO upload key: uploads/{timestamp}-{safeBase}{ext}.
     * Matches pre-refactor Web {@code s3DirectClient.generateKey()}.
     */
    static String generateByoUploadKey(String fileName) {
        long ts = System.currentTimeMillis();
        int dotIdx = fileName.lastIndexOf('.');
        String ext = dotIdx >= 0 ? fileName.substring(dotIdx) : "";
        String baseName = dotIdx >= 0 ? fileName.substring(0, dotIdx) : fileName;
        String safeBase = baseName.replaceAll("[^a-zA-Z0-9\\-_]", "_");
        return LEGACY_UPLOAD_PREFIX + ts + "-" + safeBase + ext;
    }

    private String buildProviderDocsUrlForConfig(S3Config config) {
        String providerId = S3ProviderCatalog.inferProviderId(config);
        return S3ProviderCatalog.buildCatalogResponse().getProviders().stream()
                .filter(p -> providerId.equals(p.getId()))
                .findFirst()
                .map(p -> buildProviderDocumentationUrl(p.getDocsSection()))
                .orElse(buildS3DocumentationUrl());
    }

    private static String resolveConfigRegion(S3Config config) {
        if (config.getRegion() != null && !config.getRegion().isBlank()) {
            return config.getRegion();
        }
        return S3ProviderCatalog.resolveDefaultRegion(S3ProviderCatalog.inferProviderId(config));
    }

    private static boolean resolvePathStyle(Boolean pathStyleAccessEnabled) {
        return pathStyleAccessEnabled == null || pathStyleAccessEnabled;
    }

    private String resolveSecretAccessKey(Long userId, S3Config config) {
        return userDataEncryption.decryptForUser(userId, config.getSecretAccessKey());
    }

    private static String resolveByoUserAgent(S3Config config) {
        return CstCloudClientAppSupport.resolveS3UserAgent(config.getClientApp());
    }

    private S3Client buildS3Client(Long userId, S3Config config) {
        String secretAccessKey = resolveSecretAccessKey(userId, config);
        String userAgent = resolveByoUserAgent(config);
        var builder = S3Client.builder()
                .region(Region.of(resolveConfigRegion(config)))
                .credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(config.getAccessKeyId(), secretAccessKey)))
                .endpointOverride(java.net.URI.create(config.getEndpoint()))
                .overrideConfiguration(ClientOverrideConfiguration.builder()
                        .putHeader("User-Agent", userAgent)
                        .build())
                .serviceConfiguration(S3Configuration.builder()
                        .pathStyleAccessEnabled(resolvePathStyle(config.getPathStyleAccessEnabled()))
                        .build())
                .requestChecksumCalculation(RequestChecksumCalculation.WHEN_REQUIRED)
                .responseChecksumValidation(ResponseChecksumValidation.WHEN_REQUIRED);
        TrustManager[] trustManagers = CstCloudTlsSupport.trustManagersFor(config.getEndpoint());
        if (trustManagers != null) {
            builder.httpClientBuilder(UrlConnectionHttpClient.builder()
                    .tlsTrustManagersProvider(() -> trustManagers));
        }
        return builder.build();
    }

    /**
     * S3Presigner does not expose checksum builder options in SDK 2.31; wire a configured client
     * so presigned URLs omit optional integrity headers that break third-party S3 endpoints.
     */
    private PresignerSession openPresigner(Long userId, S3Config config) {
        S3Client client = buildS3Client(userId, config);
        String secretAccessKey = resolveSecretAccessKey(userId, config);
        S3Presigner presigner = S3Presigner.builder()
                .region(Region.of(resolveConfigRegion(config)))
                .credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(config.getAccessKeyId(), secretAccessKey)))
                .endpointOverride(java.net.URI.create(config.getEndpoint()))
                .s3Client(client)
                .serviceConfiguration(S3Configuration.builder()
                        .pathStyleAccessEnabled(resolvePathStyle(config.getPathStyleAccessEnabled()))
                        .build())
                .build();
        return new PresignerSession(client, presigner);
    }

    private static final class PresignerSession implements AutoCloseable {
        private final S3Client client;
        private final S3Presigner presigner;

        private PresignerSession(S3Client client, S3Presigner presigner) {
            this.client = client;
            this.presigner = presigner;
        }

        private S3Presigner presigner() {
            return presigner;
        }

        @Override
        public void close() {
            presigner.close();
            client.close();
        }
    }
}
