package dev.ultrasend.backend.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.web.reactive.function.client.WebClient;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class SendCloudMailServiceTest {

    private SendCloudMailService service;
    private ObjectMapper objectMapper;

    @BeforeEach
    void setUp() {
        objectMapper = new ObjectMapper();
        service = new SendCloudMailService(
                "trigger_user",
                "secret_key",
                "noreply@example.com",
                "虾传",
                WebClient.create(),
                objectMapper);
    }

    @Test
    void validateResponse_acceptsSuccessResult() {
        String response = """
                {"result":true,"statusCode":200,"message":"请求成功","info":{}}
                """;

        assertDoesNotThrow(() -> service.validateResponse(response, "user@example.com"));
    }

    @Test
    void validateResponse_rejectsAuthFailure() {
        String response = """
                {"result":false,"statusCode":40005,"message":"认证失败","info":{}}
                """;

        RuntimeException ex = assertThrows(
                RuntimeException.class,
                () -> service.validateResponse(response, "user@example.com"));

        assertEquals("邮件发送失败：认证失败 (code: 40005)", ex.getMessage());
    }

    @Test
    void sendVerificationCode_rejectsMissingCredentials() {
        SendCloudMailService unconfigured = new SendCloudMailService(
                "",
                "",
                "noreply@example.com",
                "虾传",
                WebClient.create(),
                objectMapper);

        RuntimeException ex = assertThrows(
                RuntimeException.class,
                () -> unconfigured.sendVerificationCode("user@example.com", "123456"));

        assertEquals("邮件服务未配置，请联系管理员", ex.getMessage());
    }
}
