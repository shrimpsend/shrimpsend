package dev.ultrasend.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class S3ProviderCatalogItemDto {
    private String id;
    private String label;
    private String labelZh;
    private String docsSection;
    private S3ProviderDefaultsDto defaults;
    private S3ProviderFieldsDto fields;
}
