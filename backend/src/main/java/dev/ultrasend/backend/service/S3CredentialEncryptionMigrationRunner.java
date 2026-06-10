package dev.ultrasend.backend.service;

import dev.ultrasend.backend.config.UserDataEncryptionProperties;
import dev.ultrasend.backend.entity.S3Config;
import dev.ultrasend.backend.repository.S3ConfigRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Component
@RequiredArgsConstructor
@Slf4j
public class S3CredentialEncryptionMigrationRunner {

    private static final int BATCH_SIZE = 200;

    private final UserDataEncryptionProperties properties;
    private final S3ConfigRepository s3ConfigRepository;
    private final UserDataEncryptionService userDataEncryption;

    @EventListener(ApplicationReadyEvent.class)
    public void migrateOnStartup() {
        if (!properties.isMigrateS3OnStartup()) {
            return;
        }
        migratePlaintextCredentials();
    }

    @Transactional
    public void migratePlaintextCredentials() {
        long cursor = 0L;
        long scanned = 0L;
        long encrypted = 0L;
        long skipped = 0L;
        while (true) {
            List<S3Config> batch = s3ConfigRepository.findByIdGreaterThanOrderByIdAsc(
                    cursor,
                    PageRequest.of(0, BATCH_SIZE));
            if (batch.isEmpty()) {
                break;
            }
            for (S3Config config : batch) {
                cursor = config.getId();
                scanned++;
                String stored = config.getSecretAccessKey();
                if (stored == null || stored.isBlank()) {
                    skipped++;
                    continue;
                }
                if (userDataEncryption.isUserEncrypted(stored)) {
                    skipped++;
                    continue;
                }
                try {
                    Long userId = config.getUser().getId();
                    userDataEncryption.ensureUserKey(userId);
                    String plaintext = userDataEncryption.decryptForUser(userId, stored);
                    config.setSecretAccessKey(userDataEncryption.encryptForUser(userId, plaintext));
                    encrypted++;
                } catch (Exception e) {
                    log.warn("s3 credential encryption migration skipped id={} reason={}",
                            config.getId(), e.getMessage());
                }
            }
            s3ConfigRepository.saveAll(batch);
        }
        log.info("s3 credential encryption migration finished scanned={} encrypted={} skipped={}",
                scanned, encrypted, skipped);
    }
}
