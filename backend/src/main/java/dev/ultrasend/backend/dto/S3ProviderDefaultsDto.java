package dev.ultrasend.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class S3ProviderDefaultsDto {
    private String endpoint;
    private String region;
    private Boolean pathStyleAccessEnabled;
    private String endpointPlaceholder;
    private String regionPlaceholder;
}
