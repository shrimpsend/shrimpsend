package dev.ultrasend.backend.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import dev.ultrasend.backend.dto.S3ConfigResponse;
import dev.ultrasend.backend.dto.S3StorageMode;
import dev.ultrasend.backend.entity.S3Config;
import dev.ultrasend.backend.entity.User;
import dev.ultrasend.backend.repository.S3ConfigRepository;
import dev.ultrasend.backend.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class S3ServiceGetConfigTest {

    @Mock
    private S3ConfigRepository s3ConfigRepository;
    @Mock
    private UserRepository userRepository;
    @Mock
    private HostedS3Service hostedS3Service;
    @Mock
    private UserDataEncryptionService userDataEncryption;

    private S3Service s3Service;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @BeforeEach
    void setUp() {
        s3Service = new S3Service(s3ConfigRepository, userRepository, hostedS3Service, userDataEncryption);
        ReflectionTestUtils.setField(s3Service, "publicWebBaseUrl", "http://localhost:3000");
        ReflectionTestUtils.setField(s3Service, "s3DocsPath", "/zh/docs/s3/overview");
    }

    @Test
    void getConfigNeverReturnsSecretAccessKeyEvenWhenStored() throws Exception {
        User user = User.builder().id(42L).build();
        S3Config config = S3Config.builder()
                .user(user)
                .endpoint("https://s3.example.com")
                .region("cn-east-1")
                .bucket("my-bucket")
                .accessKeyId("AKIAEXAMPLE")
                .secretAccessKey("super-secret-key")
                .prefersHosted(false)
                .pathStyleAccessEnabled(true)
                .build();

        when(hostedS3Service.isActive()).thenReturn(false);
        when(s3ConfigRepository.findByUserId(42L)).thenReturn(Optional.of(config));

        S3ConfigResponse response = s3Service.getConfig(42L);

        assertEquals(S3StorageMode.CUSTOM, response.getMode());
        assertEquals("AKIAEXAMPLE", response.getAccessKeyId());

        JsonNode json = objectMapper.valueToTree(response);
        assertFalse(json.has("secretAccessKey"));
    }
}
