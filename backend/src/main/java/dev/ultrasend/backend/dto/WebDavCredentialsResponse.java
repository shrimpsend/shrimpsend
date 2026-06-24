package dev.ultrasend.backend.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.Builder;
import lombok.Data;

@Data
@Builder
@JsonInclude(JsonInclude.Include.NON_NULL)
public class WebDavCredentialsResponse {

    private String username;
    private String password;
    private String baseUrl;
    private String rootPath;
}
