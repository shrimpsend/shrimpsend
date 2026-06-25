package dev.ultrasend.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class S3TestUrlResponse {

    /** Presigned HeadBucket URL for the client to probe from its own network. */
    private String url;

    /** Server-side HeadBucket result: {@code ok}, {@code ssl_failed}, or {@code failed}. */
    private String serverProbe;

    /** AWS/S3 or TLS error detail when {@link #serverProbe} is not {@code ok}. */
    private String serverError;
}
