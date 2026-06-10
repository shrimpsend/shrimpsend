package dev.ultrasend.backend.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import dev.ultrasend.backend.config.UserDataEncryptionProperties;
import dev.ultrasend.backend.entity.Message;
import dev.ultrasend.backend.entity.User;
import dev.ultrasend.backend.repository.MessageRepository;
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
import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class MessageTextEncryptionMigrationRunnerTest {

    private static final byte[] KEK = "01234567890123456789012345678901".getBytes(StandardCharsets.UTF_8);
    private static final byte[] MSG_KEY = "12345678901234567890123456789012".getBytes(StandardCharsets.UTF_8);

    @Mock
    private MessageRepository messageRepository;
    @Mock
    private UserRepository userRepository;
    @Mock
    private Environment environment;

    private MessageCryptoService messageCryptoService;
    private UserDataEncryptionService userDataEncryption;
    private MessageTextEncryptionMigrationRunner runner;
    private ObjectMapper objectMapper;

    @BeforeEach
    void setUp() {
        var messageProperties = new dev.ultrasend.backend.config.MessageEncryptionProperties();
        messageProperties.setKeyBase64(Base64.getEncoder().encodeToString(MSG_KEY));
        messageCryptoService = new MessageCryptoService(messageProperties, environment);
        messageCryptoService.init();

        UserDataEncryptionProperties userProperties = new UserDataEncryptionProperties();
        userProperties.setKekBase64(Base64.getEncoder().encodeToString(KEK));
        userDataEncryption = new UserDataEncryptionService(userProperties, userRepository, environment);
        userDataEncryption.init();

        UserDataEncryptionProperties runnerProperties = new UserDataEncryptionProperties();
        objectMapper = new ObjectMapper();
        runner = new MessageTextEncryptionMigrationRunner(
                runnerProperties,
                messageRepository,
                messageCryptoService,
                userDataEncryption,
                objectMapper);
    }

    @Test
    void migrateLegacyMessageTextRewritesPayloadToUserDek() throws Exception {
        User user = User.builder().id(5L).build();
        String legacyText = messageCryptoService.encrypt("hello");
        String json = objectMapper.writeValueAsString(Map.of(
                "type", "text",
                "payload", Map.of("text", legacyText),
                "fromDeviceId", "device_a",
                "ts", 1L));
        Message message = Message.builder()
                .id(100L)
                .userId(5L)
                .data(json)
                .build();

        when(messageRepository.findByIdGreaterThanOrderByIdAsc(eq(0L), any()))
                .thenReturn(List.of(message));
        when(messageRepository.findByIdGreaterThanOrderByIdAsc(eq(100L), any()))
                .thenReturn(List.of());
        when(userRepository.findById(5L)).thenReturn(Optional.of(user));
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> invocation.getArgument(0));
        when(messageRepository.saveAll(any())).thenAnswer(invocation -> invocation.getArgument(0));

        runner.migrateLegacyMessageText();

        Map<String, Object> stored = objectMapper.readValue(message.getData(), Map.class);
        @SuppressWarnings("unchecked")
        Map<String, Object> payload = (Map<String, Object>) stored.get("payload");
        String migratedText = payload.get("text").toString();
        assertTrue(userDataEncryption.isUserEncrypted(migratedText));
        assertEquals("hello", userDataEncryption.decryptForUser(5L, migratedText));
    }
}
