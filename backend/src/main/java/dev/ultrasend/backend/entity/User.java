package dev.ultrasend.backend.entity;

import jakarta.persistence.*;
import lombok.*;

import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(unique = true, nullable = false)
    private String email;

    @Column(length = 128)
    private String username; // 可选展示名，默认用邮箱前缀

    @Column(nullable = false)
    private String passwordHash;

    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL, orphanRemoval = true)
    @Builder.Default
    private List<Device> devices = new ArrayList<>();

    @Column(name = "verified_mobile", length = 11)
    private String verifiedMobile; // 已验证的手机号（用于防重复）

    @Column(name = "mobile_migration_verified_at")
    private java.time.Instant mobileMigrationVerifiedAt; // 手机号验证时间

    /**
     * Per-user data encryption DEK wrapped by server KEK ({@code enc:kek:v1:}).
     */
    @Column(name = "data_encryption_key_enc", length = 512)
    private String dataEncryptionKeyEnc;
}
