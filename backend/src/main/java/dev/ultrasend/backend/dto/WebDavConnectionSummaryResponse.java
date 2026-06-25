package dev.ultrasend.backend.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.Builder;
import lombok.Data;

import java.time.Instant;

@Data
@Builder
@JsonInclude(JsonInclude.Include.NON_NULL)
public class WebDavConnectionSummaryResponse {

    private Long id;
    private String name;
    private String baseUrl;
    private String rootPath;
    private Instant updatedAt;
    private String clientApp;
}
