package dev.ultrasend.backend.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class S3ConfigRequest {

    @NotBlank
    private String endpoint;

    private String region;

    @NotBlank
    private String bucket;

    @NotBlank
    private String accessKeyId;

    /** 留空则保存时不修改已有 secret。 */
    private String secretAccessKey;

    /** null 时按 true（Path-style）保存，与历史客户端行为一致。 */
    private Boolean pathStyleAccessEnabled;

    /**
     * 数据胶囊等：与控制台创建 AccessKey 时绑定的客户端应用一致。
     * s3drive | s3browser | rclone | obsidian | cherry_studio
     */
    private String clientApp;

    /**
     * S3 服务提供商预设：custom | data_capsule | bitiful | tencent_cos | cloudflare_r2
     */
    private String providerId;
}
