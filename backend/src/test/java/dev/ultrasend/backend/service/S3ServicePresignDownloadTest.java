package dev.ultrasend.backend.service;

import dev.ultrasend.backend.config.UserDataEncryptionProperties;
import dev.ultrasend.backend.entity.S3Config;
import dev.ultrasend.backend.entity.User;
import dev.ultrasend.backend.repository.S3ConfigRepository;
import dev.ultrasend.backend.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.core.env.Environment;
import org.springframework.test.util.ReflectionTestUtils;

import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class S3ServicePresignDownloadTest {

    private static final byte[] KEK = "01234567890123456789012345678901".getBytes(StandardCharsets.UTF_8);

    @Mock
    private S3ConfigRepository s3ConfigRepository;
    @Mock
    private UserRepository userRepository;
    @Mock
    private HostedS3Service hostedS3Service;
    @Mock
    private Environment environment;

    private UserDataEncryptionService userDataEncryption;
    private S3Service s3Service;

    @BeforeEach
    void setUp() {
        UserDataEncryptionProperties properties = new UserDataEncryptionProperties();
        properties.setKekBase64(Base64.getEncoder().encodeToString(KEK));
        userDataEncryption = new UserDataEncryptionService(properties, userRepository, environment);
        userDataEncryption.init();
        s3Service = new S3Service(s3ConfigRepository, userRepository, hostedS3Service, userDataEncryption);
        ReflectionTestUtils.setField(s3Service, "publicWebBaseUrl", "http://localhost:3000");
        ReflectionTestUtils.setField(s3Service, "s3DocsPath", "/zh/docs/s3/overview");
    }

    @Test
    void presignDownloadByoAcceptsLegacyUploadsKey() {
        User user = User.builder().id(42L).build();
        when(userRepository.findById(42L)).thenReturn(Optional.of(user));
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> invocation.getArgument(0));
        when(hostedS3Service.useHostedForUser(42L)).thenReturn(false);

        String encryptedSk = userDataEncryption.encryptForUser(42L, "secret-key");
        S3Config config = S3Config.builder()
                .user(user)
                .endpoint("https://rustfsapi.example.com")
                .region("cn-east-1")
                .bucket("test")
                .accessKeyId("AKIAEXAMPLE")
                .secretAccessKey(encryptedSk)
                .pathStyleAccessEnabled(true)
                .build();
        when(s3ConfigRepository.findByUserId(42L)).thenReturn(Optional.of(config));

        String legacyKey = "uploads/1780470200736-Screenshot_2026-06-02.jpg";
        String url = s3Service.presignDownload(42L, legacyKey);

        assertNotNull(url);
        assertTrue(url.contains("X-Amz-Signature="));
        assertTrue(url.contains(legacyKey.replace("/", "%2F")) || url.contains(legacyKey),
                "Presigned URL should reference legacy object key");
    }
}
