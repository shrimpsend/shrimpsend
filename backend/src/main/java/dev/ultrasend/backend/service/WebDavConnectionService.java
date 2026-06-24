package dev.ultrasend.backend.service;

import dev.ultrasend.backend.dto.*;
import dev.ultrasend.backend.entity.User;
import dev.ultrasend.backend.entity.WebDavConnection;
import dev.ultrasend.backend.repository.UserRepository;
import dev.ultrasend.backend.repository.WebDavConnectionRepository;
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
                .build();
    }

    @Transactional
    public WebDavConnectionSummaryResponse create(Long userId, WebDavConnectionRequest req) {
        validateRequest(req, true);
        User user = userRepository.findById(userId).orElseThrow();
        String baseUrl = WebDavPropfindClient.normalizeBaseUrl(req.getBaseUrl());
        String rootPath = normalizeRootPath(req.getRootPath());

        int nextSort = webDavConnectionRepository.findByUserIdOrderBySortOrderAscIdAsc(userId).size();

        WebDavConnection conn = WebDavConnection.builder()
                .user(user)
                .name(req.getName().trim())
                .baseUrl(baseUrl)
                .usernameEnc(userDataEncryption.encryptForUser(userId, req.getUsername().trim()))
                .passwordEnc(userDataEncryption.encryptForUser(userId, req.getPassword()))
                .rootPath(rootPath)
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
                decryptPassword(userId, conn));
    }

    public WebDavTestResponse testDraft(WebDavConnectionRequest req) {
        validateRequest(req, true);
        return testWithCredentials(
                req.getBaseUrl(),
                req.getRootPath(),
                req.getUsername().trim(),
                req.getPassword());
    }

    private WebDavTestResponse testWithCredentials(
            String baseUrl,
            String rootPath,
            String username,
            String password) {
        try {
            WebDavPropfindClient.propfindDepth0(baseUrl, rootPath, username, password);
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
                .updatedAt(conn.getUpdatedAt())
                .build();
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
        }
    }
}
