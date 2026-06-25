package dev.ultrasend.backend.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.reactive.function.BodyInserters;
import org.springframework.web.reactive.function.client.WebClient;

@Service
@Slf4j
public class SendCloudMailService {

    private static final String SEND_URL = "https://api.sendcloud.net/apiv2/mail/send";

    private final String apiUser;
    private final String apiKey;
    private final String from;
    private final String fromName;
    private final WebClient webClient;
    private final ObjectMapper objectMapper;

    @Autowired
    public SendCloudMailService(
            @Value("${sendcloud.api-user}") String apiUser,
            @Value("${sendcloud.api-key}") String apiKey,
            @Value("${sendcloud.from}") String from,
            @Value("${sendcloud.from-name:虾传}") String fromName,
            ObjectMapper objectMapper) {
        this(apiUser, apiKey, from, fromName, WebClient.create(), objectMapper);
    }

    SendCloudMailService(
            String apiUser,
            String apiKey,
            String from,
            String fromName,
            WebClient webClient,
            ObjectMapper objectMapper) {
        this.apiUser = apiUser;
        this.apiKey = apiKey;
        this.from = from;
        this.fromName = fromName;
        this.webClient = webClient;
        this.objectMapper = objectMapper;

        if (isConfigured()) {
            log.info("sendcloud mail service initialized: apiUser={} from={}", apiUser, from);
        } else {
            log.warn("sendcloud mail service initialized but credentials are missing");
        }
    }

    public void sendVerificationCode(String to, String code) {
        String subject = "虾传 邮箱验证码";
        String html = buildVerificationHtml(code);
        sendMail(to, subject, html);
    }

    private void sendMail(String to, String subject, String html) {
        assertConfigured();

        MultiValueMap<String, String> formData = new LinkedMultiValueMap<>();
        formData.add("apiUser", apiUser);
        formData.add("apiKey", apiKey);
        formData.add("from", from);
        formData.add("fromName", fromName);
        formData.add("to", to);
        formData.add("subject", subject);
        formData.add("html", html);

        try {
            String response = webClient.post()
                    .uri(SEND_URL)
                    .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                    .body(BodyInserters.fromFormData(formData))
                    .retrieve()
                    .bodyToMono(String.class)
                    .block();
            validateResponse(response, to);
        } catch (RuntimeException e) {
            throw e;
        } catch (Exception e) {
            log.error("sendcloud mail request failed to={}", to, e);
            throw new RuntimeException("邮件发送失败，请稍后重试");
        }
    }

    void validateResponse(String response, String to) {
        try {
            JsonNode root = objectMapper.readTree(response);
            if (root.path("result").asBoolean(false)) {
                log.info("sendcloud mail success to={} response={}", to, response);
                return;
            }
            int statusCode = root.path("statusCode").asInt(-1);
            String message = root.path("message").asText("未知错误");
            log.error("sendcloud mail failed to={} statusCode={} message={} response={}",
                    to, statusCode, message, response);
            throw new RuntimeException("邮件发送失败：" + message + " (code: " + statusCode + ")");
        } catch (RuntimeException e) {
            throw e;
        } catch (Exception e) {
            log.error("sendcloud mail response parse failed to={} response={}", to, response, e);
            throw new RuntimeException("邮件发送失败，请稍后重试");
        }
    }

    private boolean isConfigured() {
        return apiUser != null && !apiUser.isBlank()
                && apiKey != null && !apiKey.isBlank();
    }

    private void assertConfigured() {
        if (!isConfigured()) {
            throw new RuntimeException("邮件服务未配置，请联系管理员");
        }
    }

    private String buildVerificationHtml(String code) {
        return """
                <div style="max-width:400px;margin:40px auto;font-family:system-ui,-apple-system,sans-serif;background:#f9fafb;border-radius:12px;padding:32px;text-align:center">
                  <h2 style="margin:0 0 8px;color:#111827">虾传</h2>
                  <p style="color:#6b7280;margin:0 0 24px">邮箱验证码</p>
                  <div style="font-size:32px;font-weight:700;letter-spacing:8px;color:#059669;background:#fff;border-radius:8px;padding:16px;margin:0 0 24px">%s</div>
                  <p style="color:#9ca3af;font-size:13px;margin:0">验证码 10 分钟内有效，请勿泄露给他人</p>
                </div>
                """.formatted(code);
    }
}
