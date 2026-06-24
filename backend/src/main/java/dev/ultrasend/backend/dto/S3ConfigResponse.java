package dev.ultrasend.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class S3ConfigResponse {

    /**
     * Convenience flag, equivalent to {@code mode != DISABLED}.
     * Kept for backward compatibility with older clients.
     */
    private boolean configured;

    /**
     * 当前生效的 S3 模式：DISABLED / HOSTED / CUSTOM。
     */
    private S3StorageMode mode;

    /**
     * 当前部署是否提供了内置 S3（海外集群且 hosted bucket 启用）。
     * 客户端用它来决定是否展示「切换回内置 S3」按钮。
     */
    private boolean hostedAvailable;

    /**
     * 用户是否在后端保存过自建 S3 凭证。
     * <p>
     * 当 {@code mode = HOSTED} 且 {@code customSaved = true} 时，说明用户曾经配置过自建 S3
     * 但当前选择走平台内置 S3。客户端可以据此展示「使用已保存的自建 S3」按钮，
     * 让用户一键切回，避免再次输入 AK/SK。
     */
    private boolean customSaved;

    /**
     * 当前部署下 S3 自建存储配置说明（含 CORS）文档的绝对 URL，供 Flutter/Web 外链使用。
     */
    private String documentationUrl;

    private String endpoint;
    private String region;
    private String bucket;
    private String accessKeyId;

    /** true = Path-style; false = virtual-hosted. */
    private Boolean pathStyleAccessEnabled;

    /** CSTCloud Data Capsule client binding id, if configured. */
    private String clientApp;

    /** Resolved User-Agent for direct S3 HTTP from clients (matches {@link #clientApp}). */
    private String userAgent;
}
