package dev.ultrasend.backend.controller;

import dev.ultrasend.backend.dto.*;
import dev.ultrasend.backend.service.WebDavConnectionService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/webdav/connections")
@RequiredArgsConstructor
@Slf4j
public class WebDavController {

    private final WebDavConnectionService webDavConnectionService;

    @GetMapping
    public ResponseEntity<List<WebDavConnectionSummaryResponse>> list(Authentication auth) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        return ResponseEntity.ok(webDavConnectionService.listConnections(userId));
    }

    @PostMapping
    public ResponseEntity<WebDavConnectionSummaryResponse> create(
            Authentication auth,
            @Valid @RequestBody WebDavConnectionRequest req) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        log.info("webdav create userId={}", userId);
        return ResponseEntity.ok(webDavConnectionService.create(userId, req));
    }

    @GetMapping("/{id}")
    public ResponseEntity<WebDavConnectionSummaryResponse> getMeta(
            Authentication auth,
            @PathVariable Long id) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        return ResponseEntity.ok(webDavConnectionService.getMeta(userId, id));
    }

    @PostMapping("/{id}/credentials")
    public ResponseEntity<WebDavCredentialsResponse> getCredentials(
            Authentication auth,
            @PathVariable Long id) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        log.info("webdav credentials userId={} connectionId={}", userId, id);
        return ResponseEntity.ok(webDavConnectionService.getCredentials(userId, id));
    }

    @PutMapping("/{id}")
    public ResponseEntity<WebDavConnectionSummaryResponse> update(
            Authentication auth,
            @PathVariable Long id,
            @Valid @RequestBody WebDavConnectionRequest req) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        log.info("webdav update userId={} connectionId={}", userId, id);
        return ResponseEntity.ok(webDavConnectionService.update(userId, id, req));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(Authentication auth, @PathVariable Long id) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        webDavConnectionService.delete(userId, id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{id}/test")
    public ResponseEntity<WebDavTestResponse> testExisting(
            Authentication auth,
            @PathVariable Long id) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        log.info("webdav test userId={} connectionId={}", userId, id);
        return ResponseEntity.ok(webDavConnectionService.testConnection(userId, id));
    }

    @PostMapping("/test")
    public ResponseEntity<WebDavTestResponse> testDraft(
            Authentication auth,
            @Valid @RequestBody WebDavConnectionRequest req) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        log.info("webdav testDraft userId={}", userId);
        return ResponseEntity.ok(webDavConnectionService.testDraft(req));
    }
}
