package dev.ultrasend.backend.service;

import dev.ultrasend.backend.config.UserDataEncryptionProperties;
import dev.ultrasend.backend.dto.S3ConfigRequest;
import dev.ultrasend.backend.entity.S3Config;
import dev.ultrasend.backend.entity.User;
import dev.ultrasend.backend.repository.S3ConfigRepository;
import dev.ultrasend.backend.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.core.env.Environment;
import org.springframework.test.util.ReflectionTestUtils;

import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class S3ServiceCredentialEncryptionTest {

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
    void saveConfigEncryptsSecretAccessKeyWithUserDek() {
        User user = User.builder().id(7L).build();
        when(userRepository.findById(7L)).thenReturn(Optional.of(user));
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> invocation.getArgument(0));
        when(s3ConfigRepository.findByUserId(7L)).thenReturn(Optional.empty());
        when(s3ConfigRepository.save(any(S3Config.class))).thenAnswer(invocation -> invocation.getArgument(0));

        S3ConfigRequest req = new S3ConfigRequest();
        req.setEndpoint("https://s3.example.com");
        req.setRegion("cn-east-1");
        req.setBucket("bucket");
        req.setAccessKeyId("AKIA");
        req.setSecretAccessKey("super-secret");

        s3Service.saveConfig(7L, req);

        ArgumentCaptor<S3Config> captor = ArgumentCaptor.forClass(S3Config.class);
        verify(s3ConfigRepository).save(captor.capture());
        String stored = captor.getValue().getSecretAccessKey();
        assertTrue(userDataEncryption.isUserEncrypted(stored));
        assertEquals("super-secret", userDataEncryption.decryptForUser(7L, stored));
    }
}
