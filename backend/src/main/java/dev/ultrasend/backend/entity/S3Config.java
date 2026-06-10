package dev.ultrasend.backend.entity;

import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "s3_config", uniqueConstraints = @UniqueConstraint(columnNames = "user_id"))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class S3Config {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    private String endpoint;
    private String region;
    private String bucket;
    private String accessKeyId;
    /** Stored as {@code enc:u:v1:} ciphertext (per-user DEK) after migration. */
    private String secretAccessKey;

    /**
     * 用户偏好：true 表示当前主动使用平台内置 S3，但保留这份自建配置以便随时切回。
     * 默认 false，即「BYO 存在 → 走 BYO」；与字段加入前的旧行为兼容。
     */
    @Column(name = "prefers_hosted", nullable = false)
    @Builder.Default
    private Boolean prefersHosted = false;

    /**
     * true = Path-style ({endpoint}/{bucket}/{key}); false = virtual-hosted ({bucket}.{host}/{key}).
     */
    @Column(name = "path_style_access_enabled", nullable = false)
    @Builder.Default
    private Boolean pathStyleAccessEnabled = true;
}
