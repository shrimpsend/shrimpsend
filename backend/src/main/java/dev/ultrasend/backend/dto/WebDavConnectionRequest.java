package dev.ultrasend.backend.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class WebDavConnectionRequest {

    @NotBlank
    private String name;

    @NotBlank
    private String baseUrl;

    /** Required on create; optional on update (blank keeps existing). */
    private String username;

    /** Required on create; optional on update (blank keeps existing). */
    private String password;

    private String rootPath;

    /** Required for CSTCloud Data Capsule ({@code *.cstcloud.cn}). */
    private String clientApp;
}
