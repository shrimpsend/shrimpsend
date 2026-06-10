package dev.ultrasend.backend.service;

import dev.ultrasend.backend.repository.S3ConfigRepository;
import dev.ultrasend.backend.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

@ExtendWith(MockitoExtension.class)
class S3ServiceKeyValidationTest {

    private static final Long USER_ID = 42L;

    @Mock
    private S3ConfigRepository s3ConfigRepository;
    @Mock
    private UserRepository userRepository;
    @Mock
    private HostedS3Service hostedS3Service;
    @Mock
    private UserDataEncryptionService userDataEncryption;

    private S3Service s3Service;

    @BeforeEach
    void setUp() {
        s3Service = new S3Service(s3ConfigRepository, userRepository, hostedS3Service, userDataEncryption);
        ReflectionTestUtils.setField(s3Service, "publicWebBaseUrl", "http://localhost:3000");
        ReflectionTestUtils.setField(s3Service, "s3DocsPath", "/zh/docs/s3/overview");
    }

    @Test
    void validateKeyOwnership_acceptsLegacyUploadsPrefix() {
        assertDoesNotThrow(() -> s3Service.validateKeyOwnership(
                USER_ID, "uploads/1780470200736-Screenshot_2026-06-02.jpg"));
    }

    @Test
    void validateKeyOwnership_acceptsCurrentUltrasendPrefix() {
        assertDoesNotThrow(() -> s3Service.validateKeyOwnership(
                USER_ID, "ultrasend/42/uuid/report.pdf"));
    }

    @Test
    void validateKeyOwnership_rejectsOtherUserUltrasendPrefix() {
        assertThrows(IllegalArgumentException.class, () -> s3Service.validateKeyOwnership(
                USER_ID, "ultrasend/999/uuid/report.pdf"));
    }

    @Test
    void validateKeyOwnership_rejectsPathTraversal() {
        assertThrows(IllegalArgumentException.class, () -> s3Service.validateKeyOwnership(
                USER_ID, "../etc/passwd"));
    }

    @Test
    void validateKeyOwnership_rejectsLeadingSlash() {
        assertThrows(IllegalArgumentException.class, () -> s3Service.validateKeyOwnership(
                USER_ID, "/uploads/file.jpg"));
    }

    @Test
    void validateKeyOwnership_rejectsBlankKey() {
        assertThrows(IllegalArgumentException.class, () -> s3Service.validateKeyOwnership(USER_ID, "  "));
    }

    @Test
    void generateByoUploadKey_matchesLegacyFormat() {
        String key = S3Service.generateByoUploadKey("IMG_3891.PNG");
        assertTrue(key.startsWith(S3Service.LEGACY_UPLOAD_PREFIX));
        assertTrue(key.matches("uploads/\\d+-IMG_3891\\.PNG"));
    }

    @Test
    void generateByoUploadKey_sanitizesUnsafeCharacters() {
        String key = S3Service.generateByoUploadKey("my file (1).jpg");
        assertTrue(key.endsWith("my_file__1_.jpg"));
    }
}
