package dev.ultrasend.backend.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import dev.ultrasend.backend.config.UserDataEncryptionProperties;
import dev.ultrasend.backend.entity.Message;
import dev.ultrasend.backend.repository.MessageRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Component
@RequiredArgsConstructor
@Slf4j
public class MessageTextEncryptionMigrationRunner {

    private static final int BATCH_SIZE = 200;
    private static final TypeReference<Map<String, Object>> MAP_TYPE = new TypeReference<>() {};

    private final UserDataEncryptionProperties properties;
    private final MessageRepository messageRepository;
    private final MessageCryptoService messageCryptoService;
    private final UserDataEncryptionService userDataEncryption;
    private final ObjectMapper objectMapper;

    @EventListener(ApplicationReadyEvent.class)
    public void migrateOnStartup() {
        if (!properties.isMigrateMessagesOnStartup()) {
            return;
        }
        migrateLegacyMessageText();
    }

    @Transactional
    public void migrateLegacyMessageText() {
        long cursor = 0L;
        long scanned = 0L;
        long migrated = 0L;
        long skipped = 0L;
        while (true) {
            List<Message> batch = messageRepository.findByIdGreaterThanOrderByIdAsc(
                    cursor,
                    PageRequest.of(0, BATCH_SIZE));
            if (batch.isEmpty()) {
                break;
            }
            for (Message message : batch) {
                cursor = message.getId();
                scanned++;
                try {
                    if (!migrateMessageIfNeeded(message)) {
                        skipped++;
                    } else {
                        migrated++;
                    }
                } catch (Exception e) {
                    log.warn("message text encryption migration skipped id={} reason={}",
                            message.getId(), e.getMessage());
                }
            }
            messageRepository.saveAll(batch);
        }
        log.info("message text encryption migration finished scanned={} migrated={} skipped={}",
                scanned, migrated, skipped);
    }

    private boolean migrateMessageIfNeeded(Message message) throws Exception {
        String json = messageCryptoService.decryptIfNeeded(message.getData());
        Map<String, Object> envelope = objectMapper.readValue(json, MAP_TYPE);
        if (!isTextEnvelope(envelope)) {
            return false;
        }
        Object payloadObj = envelope.get("payload");
        if (!(payloadObj instanceof Map<?, ?> payload)) {
            return false;
        }
        Object textObj = payload.get("text");
        if (!(textObj instanceof String text)) {
            return false;
        }
        if (userDataEncryption.isUserEncrypted(text)) {
            return false;
        }
        if (!messageCryptoService.isEncrypted(text)) {
            return false;
        }
        String plainText = messageCryptoService.decryptIfNeeded(text);
        Map<String, Object> payloadCopy = new LinkedHashMap<>();
        payload.forEach((key, value) -> payloadCopy.put(String.valueOf(key), value));
        payloadCopy.put("text", userDataEncryption.encryptForUser(message.getUserId(), plainText));
        envelope.put("payload", payloadCopy);
        message.setData(objectMapper.writeValueAsString(envelope));
        return true;
    }

    private static boolean isTextEnvelope(Map<String, Object> envelope) {
        Object type = envelope.get("type");
        return type != null && "text".equals(type.toString());
    }
}
