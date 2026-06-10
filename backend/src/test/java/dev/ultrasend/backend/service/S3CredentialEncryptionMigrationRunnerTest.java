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

import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class S3CredentialEncryptionMigrationRunnerTest {

    private static final byte[] KEK = "01234567890123456789012345678901".getBytes(StandardCharsets.UTF_8);

    @Mock
    private S3ConfigRepository s3ConfigRepository;
    @Mock
    private UserRepository userRepository;
    @Mock
    private Environment environment;

    private UserDataEncryptionService userDataEncryption;
    private S3CredentialEncryptionMigrationRunner runner;

    @BeforeEach
    void setUp() {
        UserDataEncryptionProperties properties = new UserDataEncryptionProperties();
        properties.setKekBase64(Base64.getEncoder().encodeToString(KEK));
        userDataEncryption = new UserDataEncryptionService(properties, userRepository, environment);
        userDataEncryption.init();
        runner = new S3CredentialEncryptionMigrationRunner(properties, s3ConfigRepository, userDataEncryption);
    }

    @Test
    void migratePlaintextCredentialsEncryptsStoredSecret() {
        User user = User.builder().id(9L).build();
        S3Config config = S3Config.builder()
                .id(1L)
                .user(user)
                .secretAccessKey("plain-sk")
                .build();
        when(s3ConfigRepository.findByIdGreaterThanOrderByIdAsc(eq(0L), any()))
                .thenReturn(List.of(config));
        when(s3ConfigRepository.findByIdGreaterThanOrderByIdAsc(eq(1L), any()))
                .thenReturn(List.of());
        when(userRepository.findById(9L)).thenReturn(Optional.of(user));
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> invocation.getArgument(0));
        when(s3ConfigRepository.saveAll(any())).thenAnswer(invocation -> invocation.getArgument(0));

        runner.migratePlaintextCredentials();

        assertTrue(userDataEncryption.isUserEncrypted(config.getSecretAccessKey()));
        assertEquals("plain-sk", userDataEncryption.decryptForUser(9L, config.getSecretAccessKey()));
    }
}
