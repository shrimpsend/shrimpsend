package dev.ultrasend.backend.crypto;

import javax.crypto.AEADBadTagException;
import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.Base64;

/**
 * AES-GCM string encryption with an explicit versioned prefix.
 */
public final class AesGcmStringCrypto {

    private static final int NONCE_BYTES = 12;
    private static final int GCM_TAG_BITS = 128;
    private static final String CIPHER = "AES/GCM/NoPadding";

    private AesGcmStringCrypto() {
    }

    public static boolean hasPrefix(String value, String prefix) {
        return value != null && value.startsWith(prefix);
    }

    public static String encrypt(byte[] key, String prefix, String plaintext, SecureRandom secureRandom) {
        if (plaintext == null) {
            throw new IllegalArgumentException("Plaintext cannot be null");
        }
        validateAesKey(key);
        try {
            byte[] nonce = new byte[NONCE_BYTES];
            secureRandom.nextBytes(nonce);
            Cipher cipher = Cipher.getInstance(CIPHER);
            cipher.init(Cipher.ENCRYPT_MODE, new SecretKeySpec(key, "AES"), new GCMParameterSpec(GCM_TAG_BITS, nonce));
            byte[] ciphertext = cipher.doFinal(plaintext.getBytes(StandardCharsets.UTF_8));
            Base64.Encoder encoder = Base64.getUrlEncoder().withoutPadding();
            return prefix + encoder.encodeToString(nonce) + ":" + encoder.encodeToString(ciphertext);
        } catch (Exception e) {
            throw new IllegalStateException("AES-GCM encryption failed", e);
        }
    }

    public static String decrypt(byte[] key, String prefix, String storedValue) {
        if (!hasPrefix(storedValue, prefix)) {
            throw new IllegalArgumentException("Value is not encrypted with prefix " + prefix);
        }
        validateAesKey(key);
        String[] parts = storedValue.substring(prefix.length()).split(":", 2);
        if (parts.length != 2) {
            throw new IllegalArgumentException("Invalid encrypted format");
        }
        try {
            Base64.Decoder decoder = Base64.getUrlDecoder();
            byte[] nonce = decoder.decode(parts[0]);
            byte[] ciphertext = decoder.decode(parts[1]);
            Cipher cipher = Cipher.getInstance(CIPHER);
            cipher.init(Cipher.DECRYPT_MODE, new SecretKeySpec(key, "AES"), new GCMParameterSpec(GCM_TAG_BITS, nonce));
            return new String(cipher.doFinal(ciphertext), StandardCharsets.UTF_8);
        } catch (AEADBadTagException e) {
            throw new IllegalArgumentException("Encrypted value authentication failed", e);
        } catch (Exception e) {
            throw new IllegalArgumentException("Encrypted value decrypt failed", e);
        }
    }

    public static void validateAesKey(byte[] key) {
        int length = key != null ? key.length : 0;
        if (length != 16 && length != 24 && length != 32) {
            throw new IllegalArgumentException("AES key must be 16, 24, or 32 bytes");
        }
    }
}
