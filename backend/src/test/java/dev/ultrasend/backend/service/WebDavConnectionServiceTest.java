package dev.ultrasend.backend.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import dev.ultrasend.backend.config.UserDataEncryptionProperties;
import dev.ultrasend.backend.dto.WebDavConnectionRequest;
import dev.ultrasend.backend.dto.WebDavConnectionSummaryResponse;
import dev.ultrasend.backend.dto.WebDavCredentialsResponse;
import dev.ultrasend.backend.entity.User;
import dev.ultrasend.backend.entity.WebDavConnection;
import dev.ultrasend.backend.repository.UserRepository;
import dev.ultrasend.backend.repository.WebDavConnectionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.core.env.Environment;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Base64;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class WebDavConnectionServiceTest {

    private static final byte[] KEK = "01234567890123456789012345678901".getBytes(StandardCharsets.UTF_8);

    @Mock
    private WebDavConnectionRepository webDavConnectionRepository;
    @Mock
    private UserRepository userRepository;
    @Mock
    private MembershipService membershipService;
    @Mock
    private Environment environment;

    private UserDataEncryptionService userDataEncryption;
    private WebDavConnectionService service;
    private final ObjectMapper objectMapper = new ObjectMapper().registerModule(new JavaTimeModule());

    @BeforeEach
    void setUp() {
        UserDataEncryptionProperties properties = new UserDataEncryptionProperties();
        properties.setKekBase64(Base64.getEncoder().encodeToString(KEK));
        userDataEncryption = new UserDataEncryptionService(properties, userRepository, environment);
        userDataEncryption.init();
        service = new WebDavConnectionService(
                webDavConnectionRepository, userRepository, userDataEncryption, membershipService);
    }

    private WebDavConnectionRequest sampleCreateRequest() {
        WebDavConnectionRequest req = new WebDavConnectionRequest();
        req.setName("NAS");
        req.setBaseUrl("https://dav.example.com");
        req.setUsername("alice");
        req.setPassword("secret-pass");
        req.setRootPath("/files");
        return req;
    }

    @Test
    void createRejectedForFreeUser() {
        doThrow(new IllegalArgumentException(MembershipService.WEBDAV_MEMBER_ONLY_MESSAGE))
                .when(membershipService).ensureCanAddWebDav(7L);

        IllegalArgumentException ex = assertThrows(
                IllegalArgumentException.class,
                () -> service.create(7L, sampleCreateRequest()));
        assertEquals(MembershipService.WEBDAV_MEMBER_ONLY_MESSAGE, ex.getMessage());
    }

    @Test
    void testDraftRejectedForFreeUser() {
        doThrow(new IllegalArgumentException(MembershipService.WEBDAV_MEMBER_ONLY_MESSAGE))
                .when(membershipService).ensureCanAddWebDav(7L);

        IllegalArgumentException ex = assertThrows(
                IllegalArgumentException.class,
                () -> service.testDraft(7L, sampleCreateRequest()));
        assertEquals(MembershipService.WEBDAV_MEMBER_ONLY_MESSAGE, ex.getMessage());
    }

    @Test
    void createEncryptsUsernameAndPassword() {
        User user = User.builder().id(7L).build();
        when(userRepository.findById(7L)).thenReturn(Optional.of(user));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));
        when(webDavConnectionRepository.findByUserIdOrderBySortOrderAscIdAsc(7L)).thenReturn(List.of());
        when(webDavConnectionRepository.save(any())).thenAnswer(inv -> {
            WebDavConnection c = inv.getArgument(0);
            c.setId(99L);
            c.setUpdatedAt(Instant.now());
            return c;
        });

        WebDavConnectionRequest req = sampleCreateRequest();

        service.create(7L, req);

        verify(membershipService).ensureCanAddWebDav(eq(7L));

        ArgumentCaptor<WebDavConnection> captor = ArgumentCaptor.forClass(WebDavConnection.class);
        verify(webDavConnectionRepository).save(captor.capture());
        WebDavConnection saved = captor.getValue();
        assertTrue(saved.getUsernameEnc().startsWith(UserDataEncryptionService.PREFIX_USER));
        assertTrue(saved.getPasswordEnc().startsWith(UserDataEncryptionService.PREFIX_USER));
        assertEquals("alice", userDataEncryption.decryptForUser(7L, saved.getUsernameEnc()));
        assertEquals("secret-pass", userDataEncryption.decryptForUser(7L, saved.getPasswordEnc()));
    }

    @Test
    void listSummaryNeverContainsCredentials() throws Exception {
        User user = User.builder().id(7L).build();
        when(userRepository.findById(7L)).thenReturn(Optional.of(user));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));
        String userEnc = userDataEncryption.encryptForUser(7L, "alice");
        String passEnc = userDataEncryption.encryptForUser(7L, "secret");
        WebDavConnection conn = WebDavConnection.builder()
                .id(1L)
                .user(user)
                .name("NAS")
                .baseUrl("https://dav.example.com")
                .usernameEnc(userEnc)
                .passwordEnc(passEnc)
                .rootPath("/")
                .sortOrder(0)
                .updatedAt(Instant.now())
                .build();
        when(webDavConnectionRepository.findByUserIdOrderBySortOrderAscIdAsc(7L))
                .thenReturn(List.of(conn));

        List<WebDavConnectionSummaryResponse> list = service.listConnections(7L);
        assertEquals(1, list.size());
        JsonNode json = objectMapper.valueToTree(list.get(0));
        assertFalse(json.has("username"));
        assertFalse(json.has("password"));
        assertFalse(json.has("usernameEnc"));
        assertFalse(json.has("passwordEnc"));
    }

    @Test
    void getCredentialsReturnsDecryptedValues() {
        User user = User.builder().id(7L).build();
        when(userRepository.findById(7L)).thenReturn(Optional.of(user));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));
        String userEnc = userDataEncryption.encryptForUser(7L, "bob");
        String passEnc = userDataEncryption.encryptForUser(7L, "pw123");
        WebDavConnection conn = WebDavConnection.builder()
                .id(5L)
                .user(user)
                .name("NAS")
                .baseUrl("https://dav.example.com")
                .usernameEnc(userEnc)
                .passwordEnc(passEnc)
                .rootPath("/docs")
                .build();
        when(webDavConnectionRepository.findByIdAndUserId(5L, 7L)).thenReturn(Optional.of(conn));

        WebDavCredentialsResponse creds = service.getCredentials(7L, 5L);
        assertEquals("bob", creds.getUsername());
        assertEquals("pw123", creds.getPassword());
        assertEquals("https://dav.example.com", creds.getBaseUrl());
        assertEquals("/docs", creds.getRootPath());
    }
}
