package dev.ultrasend.backend.controller;

import dev.ultrasend.backend.dto.*;
import dev.ultrasend.backend.service.S3Service;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/s3")
@RequiredArgsConstructor
@Slf4j
public class S3Controller {

    private final S3Service s3Service;

    private static Long parseLongOrNull(Object v) {
        if (v == null) {
            return null;
        }
        if (v instanceof Number n) {
            return n.longValue();
        }
        String s = v.toString().trim();
        if (s.isEmpty()) {
            return null;
        }
        try {
            return Long.parseLong(s);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    @PostMapping("/config")
    public ResponseEntity<Void> saveConfig(Authentication auth, @Valid @RequestBody S3ConfigRequest req) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        log.info("s3 saveConfig userId={} endpoint={} bucket={}", userId, req.getEndpoint(), req.getBucket());
        s3Service.saveConfig(userId, req);
        log.info("s3 saveConfig ok userId={}", userId);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/config")
    public ResponseEntity<S3ConfigResponse> getConfig(Authentication auth) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        log.debug("s3 getConfig userId={}", userId);
        return ResponseEntity.ok(s3Service.getConfig(userId));
    }

    @DeleteMapping("/config")
    public ResponseEntity<Void> deleteConfig(Authentication auth) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        s3Service.deleteConfig(userId);
        return ResponseEntity.noContent().build();
    }

    /**
     * 切换到平台内置 S3，但保留已保存的自建 S3 凭证。
     * 用于 Web/Flutter 设置页的「切回内置 S3」按钮，避免清空配置。
     */
    @PostMapping("/use-hosted")
    public ResponseEntity<Void> useHosted(Authentication auth) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        log.info("s3 useHosted userId={}", userId);
        s3Service.preferHosted(userId);
        return ResponseEntity.noContent().build();
    }

    /**
     * 切换到此前保存的自建 S3 配置。
     */
    @PostMapping("/use-custom")
    public ResponseEntity<Void> useCustom(Authentication auth) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        log.info("s3 useCustom userId={}", userId);
        s3Service.preferCustom(userId);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/test")
    public ResponseEntity<S3TestUrlResponse> testConfig(Authentication auth) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        log.info("s3 presignTestUrl userId={}", userId);
        S3TestUrlResponse res = s3Service.presignTestUrl(userId);
        log.info("s3 presignTestUrl ok userId={}", userId);
        return ResponseEntity.ok(res);
    }

    @PostMapping("/presign-upload")
    public ResponseEntity<PresignUploadResponse> presignUpload(
            Authentication auth,
            @RequestBody Map<String, Object> body) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        String fileName = body.getOrDefault("fileName", "file").toString();
        String contentType = body.get("contentType") != null ? body.get("contentType").toString() : null;
        Long contentLength = parseLongOrNull(body.get("contentLength"));
        log.info("s3 presignUpload userId={} fileName={}", userId, fileName);
        PresignUploadResponse res = s3Service.presignUpload(userId, fileName, contentType, contentLength);
        log.debug("s3 presignUpload ok userId={} key={}", userId, res.getKey());
        return ResponseEntity.ok(res);
    }

    @GetMapping("/download-url")
    public ResponseEntity<Map<String, String>> getDownloadUrl(Authentication auth, @RequestParam String key) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        log.info("s3 getDownloadUrl userId={} key={}", userId, key);
        String url = s3Service.presignDownload(userId, key);
        return ResponseEntity.ok(Map.of("url", url));
    }

    // ── Multipart Upload ───────────────────────────────────────────────

    @PostMapping("/multipart/initiate")
    public ResponseEntity<MultipartInitiateResponse> initiateMultipart(
            Authentication auth,
            @RequestBody MultipartInitiateRequest req) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        log.info("s3 multipart initiate userId={} fileName={}", userId, req.getFileName());
        MultipartInitiateResponse res = s3Service.initiateMultipartUpload(
                userId, req.getFileName(), req.getContentType(), req.getTotalSize());
        return ResponseEntity.ok(res);
    }

    @PostMapping("/multipart/presign-part")
    public ResponseEntity<Map<String, String>> presignPart(
            Authentication auth,
            @RequestBody MultipartPresignPartRequest req) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        log.debug("s3 multipart presign-part userId={} part={}", userId, req.getPartNumber());
        String url = s3Service.presignUploadPart(userId, req.getUploadId(), req.getKey(), req.getPartNumber());
        return ResponseEntity.ok(Map.of("url", url));
    }

    @PostMapping("/multipart/complete")
    public ResponseEntity<Void> completeMultipart(
            Authentication auth,
            @RequestBody MultipartCompleteRequest req) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        log.info("s3 multipart complete userId={} key={}", userId, req.getKey());
        s3Service.completeMultipartUpload(userId, req.getUploadId(), req.getKey(), req.getParts());
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/multipart/abort")
    public ResponseEntity<Void> abortMultipart(
            Authentication auth,
            @RequestBody MultipartAbortRequest req) {
        Long userId = Long.parseLong((String) auth.getPrincipal());
        log.info("s3 multipart abort userId={} key={}", userId, req.getKey());
        s3Service.abortMultipartUpload(userId, req.getUploadId(), req.getKey());
        return ResponseEntity.noContent().build();
    }
}
