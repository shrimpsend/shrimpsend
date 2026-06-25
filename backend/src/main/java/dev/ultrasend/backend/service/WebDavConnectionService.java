package dev.ultrasend.backend.service;

import dev.ultrasend.backend.dto.*;
import dev.ultrasend.backend.entity.User;
import dev.ultrasend.backend.entity.WebDavConnection;
import dev.ultrasend.backend.repository.UserRepository;
import dev.ultrasend.backend.repository.WebDavConnectionRepository;
import dev.ultrasend.backend.cstcloud.CstCloudClientAppSupport;
import dev.ultrasend.backend.tls.CstCloudTlsSupport;
import dev.ultrasend.backend.webdav.WebDavPropfindClient;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
@Slf4j
public class WebDavConnectionService {

    private final WebDavConnectionRepository webDavConnectionRepository;
    private final UserRepository userRepository;
    private final UserDataEncryptionService userDataEncryption;

    public List<WebDavConnectionSummaryResponse> listConnections(Long userId) {
        return webDavConnectionRepository.findByUserIdOrderBySortOrderAscIdAsc(userId).stream()
                .map(this::toSummary)
                .toList();
    }

    public WebDavConnectionSummaryResponse getMeta(Long userId, Long connectionId) {
        WebDavConnection conn = requireOwned(userId, connectionId);
        return toSummary(conn);
    }

    public WebDavCredentialsResponse getCredentials(Long userId, Long connectionId) {
        WebDavConnection conn = requireOwned(userId, connectionId);
        return WebDavCredentialsResponse.builder()
                .username(decryptUsername(userId, conn))
                .password(decryptPassword(userId, conn))
                .baseUrl(conn.getBaseUrl())
                .rootPath(normalizeRootPath(conn.getRootPath()))
                .clientApp(conn.getClientApp())
                .userAgent(resolveUserAgent(conn))
                .build();
    }

    @Transactional
    public WebDavConnectionSummaryResponse create(Long userId, WebDavConnectionRequest req) {
        validateRequest(req, true);
        User user = userRepository.findById(userId).orElseThrow();
        String baseUrl = WebDavPropfindClient.normalizeBaseUrl(req.getBaseUrl());
        String rootPath = normalizeRootPath(req.getRootPath());
        CstCloudClientAppSupport.validateWebDavClientApp(baseUrl, req.getClientApp());
        String clientApp = normalizeClientApp(baseUrl, req.getClientApp());

        int nextSort = webDavConnectionRepository.findByUserIdOrderBySortOrderAscIdAsc(userId).size();

        WebDavConnection conn = WebDavConnection.builder()
                .user(user)
                .name(req.getName().trim())
                .baseUrl(baseUrl)
                .usernameEnc(userDataEncryption.encryptForUser(userId, req.getUsername().trim()))
                .passwordEnc(userDataEncryption.encryptForUser(userId, req.getPassword()))
                .rootPath(rootPath)
                .clientApp(clientApp)
                .sortOrder(nextSort)
                .build();

        conn = webDavConnectionRepository.save(conn);
        log.info("webdav create userId={} connectionId={}", userId, conn.getId());
        return toSummary(conn);
    }

    @Transactional
    public WebDavConnectionSummaryResponse update(Long userId, Long connectionId, WebDavConnectionRequest req) {
        validateRequest(req, false);
        WebDavConnection conn = requireOwned(userId, connectionId);

        if (req.getName() != null && !req.getName().isBlank()) {
            conn.setName(req.getName().trim());
        }
        if (req.getBaseUrl() != null && !req.getBaseUrl().isBlank()) {
            conn.setBaseUrl(WebDavPropfindClient.normalizeBaseUrl(req.getBaseUrl()));
        }
        if (req.getRootPath() != null) {
            conn.setRootPath(normalizeRootPath(req.getRootPath()));
        }
        if (req.getClientApp() != null && !req.getClientApp().isBlank()) {
            CstCloudClientAppSupport.validateWebDavClientApp(conn.getBaseUrl(), req.getClientApp());
            conn.setClientApp(normalizeClientApp(conn.getBaseUrl(), req.getClientApp()));
        } else if (req.getBaseUrl() != null && !req.getBaseUrl().isBlank()) {
            conn.setClientApp(normalizeClientApp(conn.getBaseUrl(), conn.getClientApp()));
        }
        if (req.getUsername() != null && !req.getUsername().isBlank()) {
            conn.setUsernameEnc(userDataEncryption.encryptForUser(userId, req.getUsername().trim()));
        }
        if (req.getPassword() != null && !req.getPassword().isBlank()) {
            conn.setPasswordEnc(userDataEncryption.encryptForUser(userId, req.getPassword()));
        }

        conn = webDavConnectionRepository.save(conn);
        log.info("webdav update userId={} connectionId={}", userId, connectionId);
        return toSummary(conn);
    }

    @Transactional
    public void delete(Long userId, Long connectionId) {
        WebDavConnection conn = requireOwned(userId, connectionId);
        webDavConnectionRepository.delete(conn);
        log.info("webdav delete userId={} connectionId={}", userId, connectionId);
    }

    public WebDavTestResponse testConnection(Long userId, Long connectionId) {
        WebDavConnection conn = requireOwned(userId, connectionId);
        return testWithCredentials(
                conn.getBaseUrl(),
                conn.getRootPath(),
                decryptUsername(userId, conn),
                decryptPassword(userId, conn),
                conn.getClientApp());
    }

    public WebDavTestResponse testDraft(WebDavConnectionRequest req) {
        validateRequest(req, true);
        String baseUrl = WebDavPropfindClient.normalizeBaseUrl(req.getBaseUrl());
        CstCloudClientAppSupport.validateWebDavClientApp(baseUrl, req.getClientApp());
        return testWithCredentials(
                req.getBaseUrl(),
                req.getRootPath(),
                req.getUsername().trim(),
                req.getPassword(),
                req.getClientApp());
    }

    private WebDavTestResponse testWithCredentials(
            String baseUrl,
            String rootPath,
            String username,
            String password,
            String clientApp) {
        try {
            String userAgent = resolveUserAgent(baseUrl, clientApp);
            WebDavPropfindClient.propfindDepth0(
                    baseUrl, rootPath, username, password, userAgent);
            return WebDavTestResponse.builder()
                    .ok(true)
                    .message("Connection successful")
                    .build();
        } catch (IllegalArgumentException e) {
            log.info("webdav test failed: {}", e.getMessage());
            return WebDavTestResponse.builder()
                    .ok(false)
                    .message(e.getMessage())
                    .build();
        } catch (Exception e) {
            if (CstCloudTlsSupport.isSslProbeError(e.getMessage(), e)) {
                log.info("webdav test failed: ssl_failed {}", e.getMessage());
                return WebDavTestResponse.builder()
                        .ok(false)
                        .message("TLS certificate verification failed")
                        .build();
            }
            log.info("webdav test failed: {}", e.getClass().getSimpleName());
            return WebDavTestResponse.builder()
                    .ok(false)
                    .message("Unable to reach WebDAV server")
                    .build();
        }
    }

    private WebDavConnection requireOwned(Long userId, Long connectionId) {
        return webDavConnectionRepository.findByIdAndUserId(connectionId, userId)
                .orElseThrow(() -> new IllegalArgumentException("WebDAV connection not found"));
    }

    private WebDavConnectionSummaryResponse toSummary(WebDavConnection conn) {
        return WebDavConnectionSummaryResponse.builder()
                .id(conn.getId())
                .name(conn.getName())
                .baseUrl(conn.getBaseUrl())
                .rootPath(normalizeRootPath(conn.getRootPath()))
                .clientApp(conn.getClientApp())
                .updatedAt(conn.getUpdatedAt())
                .build();
    }

    private static String resolveUserAgent(WebDavConnection conn) {
        return resolveUserAgent(conn.getBaseUrl(), conn.getClientApp());
    }

    private static String resolveUserAgent(String baseUrl, String clientApp) {
        if (!CstCloudClientAppSupport.needsClientAppBinding(baseUrl)) {
            return null;
        }
        return CstCloudClientAppSupport.resolveWebDavUserAgent(clientApp);
    }

    private static String normalizeClientApp(String baseUrl, String clientApp) {
        if (!CstCloudClientAppSupport.needsClientAppBinding(baseUrl)) {
            return null;
        }
        if (clientApp == null || clientApp.isBlank()) {
            return "zotero";
        }
        return clientApp.trim().toLowerCase();
    }

    private String decryptUsername(Long userId, WebDavConnection conn) {
        return userDataEncryption.decryptForUser(userId, conn.getUsernameEnc());
    }

    private String decryptPassword(Long userId, WebDavConnection conn) {
        return userDataEncryption.decryptForUser(userId, conn.getPasswordEnc());
    }

    private static String normalizeRootPath(String rootPath) {
        return WebDavPropfindClient.normalizeRootPath(rootPath);
    }

    private static void validateRequest(WebDavConnectionRequest req, boolean creating) {
        if (req.getName() == null || req.getName().isBlank()) {
            if (creating) {
                throw new IllegalArgumentException("name is required");
            }
        }
        if (creating) {
            if (req.getBaseUrl() == null || req.getBaseUrl().isBlank()) {
                throw new IllegalArgumentException("baseUrl is required");
            }
            if (req.getUsername() == null || req.getUsername().isBlank()) {
                throw new IllegalArgumentException("username is required");
            }
            if (req.getPassword() == null || req.getPassword().isBlank()) {
                throw new IllegalArgumentException("password is required");
            }
        }
        if (req.getBaseUrl() != null && !req.getBaseUrl().isBlank()) {
            WebDavPropfindClient.normalizeBaseUrl(req.getBaseUrl());
            if (creating) {
                CstCloudClientAppSupport.validateWebDavClientApp(req.getBaseUrl(), req.getClientApp());
            }
        }
    }
}
