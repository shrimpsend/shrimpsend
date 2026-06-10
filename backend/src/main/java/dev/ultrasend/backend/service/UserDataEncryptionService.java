package dev.ultrasend.backend.service;

import dev.ultrasend.backend.config.UserDataEncryptionProperties;
import dev.ultrasend.backend.crypto.AesGcmStringCrypto;
import dev.ultrasend.backend.entity.User;
import dev.ultrasend.backend.repository.UserRepository;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.util.Arrays;
import java.util.Base64;

@Service
@RequiredArgsConstructor
public class UserDataEncryptionService {

    public static final String PREFIX_USER = "enc:u:v1:";
    public static final String PREFIX_KEK = "enc:kek:v1:";

    private final UserDataEncryptionProperties properties;
    private final UserRepository userRepository;
    private final Environment environment;
    private final SecureRandom secureRandom = new SecureRandom();

    private byte[] kekBytes;

    @PostConstruct
    void init() {
        kekBytes = configuredKek();
        AesGcmStringCrypto.validateAesKey(kekBytes);
    }

    public boolean isUserEncrypted(String value) {
        return AesGcmStringCrypto.hasPrefix(value, PREFIX_USER);
    }

    @Transactional
    public void ensureUserKey(Long userId) {
        User user = userRepository.findById(userId).orElseThrow();
        if (user.getDataEncryptionKeyEnc() != null && !user.getDataEncryptionKeyEnc().isBlank()) {
            return;
        }
        byte[] dek = new byte[32];
        secureRandom.nextBytes(dek);
        String dekPlain = Base64.getEncoder().encodeToString(dek);
        user.setDataEncryptionKeyEnc(AesGcmStringCrypto.encrypt(kekBytes, PREFIX_KEK, dekPlain, secureRandom));
        userRepository.save(user);
    }

    @Transactional
    public String encryptForUser(Long userId, String plaintext) {
        if (plaintext == null) {
            throw new IllegalArgumentException("Plaintext cannot be null");
        }
        if (isUserEncrypted(plaintext)) {
            return plaintext;
        }
        ensureUserKey(userId);
        byte[] dek = loadUserDek(userId);
        return AesGcmStringCrypto.encrypt(dek, PREFIX_USER, plaintext, secureRandom);
    }

    public String decryptForUser(Long userId, String stored) {
        if (stored == null) {
            return null;
        }
        if (!isUserEncrypted(stored)) {
            return stored;
        }
        byte[] dek = loadUserDek(userId);
        return AesGcmStringCrypto.decrypt(dek, PREFIX_USER, stored);
    }

    private byte[] loadUserDek(Long userId) {
        User user = userRepository.findById(userId).orElseThrow();
        String wrapped = user.getDataEncryptionKeyEnc();
        if (wrapped == null || wrapped.isBlank()) {
            throw new IllegalStateException("User DEK not initialized for userId=" + userId);
        }
        String dekPlain = AesGcmStringCrypto.decrypt(kekBytes, PREFIX_KEK, wrapped);
        return Base64.getDecoder().decode(dekPlain);
    }

    private byte[] configuredKek() {
        String raw = properties.getKekBase64();
        if (raw != null && !raw.isBlank()) {
            return Base64.getDecoder().decode(raw.trim());
        }
        if (isProdLikeProfile() || !properties.isAllowDevFallbackKek()) {
            throw new IllegalStateException("app.user-data.encryption.kek-base64 is required");
        }
        throw new IllegalStateException(
                "app.user-data.encryption.kek-base64 is required for local dev; "
                        + "run scripts/setup-local-config.sh to generate backend/.env");
    }

    private boolean isProdLikeProfile() {
        return Arrays.stream(environment.getActiveProfiles())
                .anyMatch(profile -> profile.equals("prod") || profile.startsWith("prod-"));
    }
}
