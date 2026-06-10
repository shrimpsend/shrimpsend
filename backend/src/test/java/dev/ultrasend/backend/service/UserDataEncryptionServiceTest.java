package dev.ultrasend.backend.service;

import dev.ultrasend.backend.config.UserDataEncryptionProperties;
import dev.ultrasend.backend.entity.User;
import dev.ultrasend.backend.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.core.env.Environment;

import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class UserDataEncryptionServiceTest {

    private static final byte[] KEK = "01234567890123456789012345678901".getBytes(StandardCharsets.UTF_8);

    @Mock
    private UserRepository userRepository;
    @Mock
    private Environment environment;

    private UserDataEncryptionService service;

    @BeforeEach
    void setUp() {
        UserDataEncryptionProperties properties = new UserDataEncryptionProperties();
        properties.setKekBase64(Base64.getEncoder().encodeToString(KEK));
        service = new UserDataEncryptionService(properties, userRepository, environment);
        service.init();
    }

    @Test
    void encryptForUserGeneratesDistinctKeysPerUser() {
        User user1 = User.builder().id(1L).build();
        User user2 = User.builder().id(2L).build();
        when(userRepository.findById(1L)).thenReturn(Optional.of(user1));
        when(userRepository.findById(2L)).thenReturn(Optional.of(user2));
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> invocation.getArgument(0));

        String enc1 = service.encryptForUser(1L, "secret-a");
        String enc2 = service.encryptForUser(2L, "secret-a");

        assertTrue(service.isUserEncrypted(enc1));
        assertTrue(service.isUserEncrypted(enc2));
        assertNotEquals(enc1, enc2);
        assertEquals("secret-a", service.decryptForUser(1L, enc1));
        assertEquals("secret-a", service.decryptForUser(2L, enc2));
    }

    @Test
    void decryptForUserReturnsPlaintextWhenNotEncrypted() {
        assertEquals("plain-sk", service.decryptForUser(3L, "plain-sk"));
    }

    @Test
    void ensureUserKeyPersistsWrappedDek() {
        User user = User.builder().id(4L).build();
        when(userRepository.findById(4L)).thenReturn(Optional.of(user));
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> invocation.getArgument(0));

        service.ensureUserKey(4L);

        ArgumentCaptor<User> captor = ArgumentCaptor.forClass(User.class);
        verify(userRepository).save(captor.capture());
        assertNotNull(captor.getValue().getDataEncryptionKeyEnc());
        assertTrue(captor.getValue().getDataEncryptionKeyEnc().startsWith(UserDataEncryptionService.PREFIX_KEK));
    }
}
