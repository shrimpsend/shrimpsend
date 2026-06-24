package dev.ultrasend.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class S3ProviderFieldsDto {
    /** fixed | editable */
    private String endpoint;
    /** fixed | editable | readonly */
    private String region;
    /** fixed | editable */
    private String pathStyle;
    /** required | hidden */
    private String clientApp;
    private boolean tencentRegionPicker;
}
