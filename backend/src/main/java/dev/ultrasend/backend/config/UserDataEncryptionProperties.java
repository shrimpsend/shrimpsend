package dev.ultrasend.backend.config;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;

@Getter
@Setter
@ConfigurationProperties(prefix = "app.user-data.encryption")
public class UserDataEncryptionProperties {

    /**
     * Base64-encoded server KEK used to wrap per-user DEKs stored in users.data_encryption_key_enc.
     */
    private String kekBase64 = "";

    /**
     * Allows local development and tests to boot without a configured KEK.
     */
    private boolean allowDevFallbackKek = true;

    /**
     * One-shot migration for plaintext / legacy S3 secret_access_key rows.
     */
    private boolean migrateS3OnStartup = false;

    /**
     * One-shot migration for legacy enc:v1: message payload.text rows.
     */
    private boolean migrateMessagesOnStartup = false;
}
