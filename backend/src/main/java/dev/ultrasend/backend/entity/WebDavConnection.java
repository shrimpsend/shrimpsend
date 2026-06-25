package dev.ultrasend.backend.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.Instant;

@Entity
@Table(name = "webdav_connections")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class WebDavConnection {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false, length = 128)
    private String name;

    @Column(name = "base_url", nullable = false, length = 512)
    private String baseUrl;

    /** Stored as {@code enc:u:v1:} ciphertext (per-user DEK). */
    @Column(name = "username_enc", nullable = false, length = 1024)
    private String usernameEnc;

    /** Stored as {@code enc:u:v1:} ciphertext (per-user DEK). */
    @Column(name = "password_enc", nullable = false, length = 1024)
    private String passwordEnc;

    @Column(name = "root_path", length = 512)
    @Builder.Default
    private String rootPath = "/";

    /** CSTCloud Data Capsule client app id (e.g. zotero); binds User-Agent for WebDAV. */
    @Column(name = "client_app", length = 64)
    private String clientApp;

    @Column(name = "sort_order", nullable = false)
    @Builder.Default
    private Integer sortOrder = 0;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    void onCreate() {
        Instant now = Instant.now();
        if (createdAt == null) {
            createdAt = now;
        }
        updatedAt = now;
    }

    @PreUpdate
    void onUpdate() {
        updatedAt = Instant.now();
    }
}
