package dev.ultrasend.backend.dto;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class WebDavTestResponse {

    private boolean ok;
    private String message;
}
