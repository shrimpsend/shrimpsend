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
}
