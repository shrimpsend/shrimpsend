package dev.ultrasend.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class S3ProvidersResponse {
    private List<S3ProviderCatalogItemDto> providers;
    private List<S3ClientAppOptionDto> clientAppOptions;
    private List<S3TencentCosRegionDto> tencentCosRegions;
}
