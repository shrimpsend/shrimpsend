package dev.ultrasend.backend.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.core.type.TypeReference;
import dev.ultrasend.backend.chat.ThreadKeyUtil;
import dev.ultrasend.backend.centrifugo.CentrifugoPublishService;
import dev.ultrasend.backend.entity.Message;
import dev.ultrasend.backend.repository.MessageRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class MessageService {

    private static final TypeReference<Map<String, Object>> MAP_TYPE = new TypeReference<>() {};

    private static final Set<String> EPHEMERAL_TYPES = Set.of(
            "lan_file_offer", "lan_pull_probe", "lan_pull_probe_result",
            "lan_http_probe", "lan_http_probe_result",
            "webrtc_probe", "webrtc_probe_result",
            "webrtc_offer", "webrtc_answer", "webrtc_ice_candidate", "webrtc_transfer_cancel");

    private final MessageRepository messageRepository;
    private final CentrifugoPublishService centrifugoPublishService;
    private final ObjectMapper objectMapper;
    private final MessageCryptoService messageCryptoService;
    private final UserDataEncryptionService userDataEncryption;

    @Transactional
    public void send(String userId, Object data) {
        Long uid = Long.parseLong(userId);
        if (data instanceof Map<?, ?> rawMap) {
            @SuppressWarnings("unchecked")
            Map<String, Object> map = (Map<String, Object>) rawMap;
            ensureThreadKey(userId, map);
            data = map;
        }
        String type = null;
        if (data instanceof Map<?, ?> map) {
            Object t = map.get("type");
            if (t != null) type = t.toString();
        }

        boolean ephemeral = type != null && EPHEMERAL_TYPES.contains(type);
        if (!ephemeral) {
            String json;
            try {
                Object storedData = data instanceof Map<?, ?> rawMap
                        ? encryptTextPayloadWithUserKey(uid, asStringObjectMap(rawMap))
                        : data;
                json = objectMapper.writeValueAsString(storedData);
            } catch (Exception e) {
                log.warn("message data serialize failed: {}", e.getMessage());
                throw new IllegalArgumentException("Invalid message data");
            }
            Message msg = Message.builder()
                    .userId(uid)
                    .data(json)
                    .build();
            messageRepository.save(msg);
            log.debug("message saved userId={} id={}", userId, msg.getId());
        } else {
            log.debug("ephemeral message (type={}) not persisted, broadcast only", type);
        }
        centrifugoPublishService.publishToUser(userId, data);
    }

    /** Ensures persisted envelopes carry a canonical {@code threadKey}. */
    private void ensureThreadKey(String userId, Map<String, Object> map) {
        Object fromObj = map.get("fromDeviceId");
        String from = fromObj != null ? fromObj.toString() : "";
        String to = map.get("toDeviceId") != null ? map.get("toDeviceId").toString() : null;
        String explicit = map.get("threadKey") != null ? map.get("threadKey").toString() : null;
        String tk = ThreadKeyUtil.deriveThreadKeyForStoredMessage(userId, from, to, null, explicit);
        map.put("threadKey", tk);
    }

    @Transactional
    public void deleteMessage(Long userId, Long messageId) {
        messageRepository.deleteByIdAndUserId(messageId, userId);
        log.info("message deleted userId={} messageId={}", userId, messageId);
    }

    /** Deletes all persisted messages whose envelope {@code threadKey} matches. */
    @Transactional
    public int deleteMessagesByThreadKey(Long userId, String threadKey) {
        if (threadKey == null || threadKey.isBlank()) {
            throw new IllegalArgumentException("threadKey required");
        }
        int deleted = 0;
        Long cursor = null;
        final int batchSize = 100;
        for (int attempt = 0; attempt < 500; attempt++) {
            List<Message> batch;
            var page = org.springframework.data.domain.PageRequest.of(0, batchSize);
            if (cursor != null && cursor > 0) {
                batch = messageRepository.findByUserIdAndIdLessThanOrderByCreatedAtDesc(userId, cursor, page);
            } else {
                batch = messageRepository.findByUserIdOrderByCreatedAtDesc(userId, page);
            }
            if (batch.isEmpty()) {
                break;
            }
            for (Message message : batch) {
                if (messageMatchesThreadKey(message, threadKey)) {
                    messageRepository.deleteByIdAndUserId(message.getId(), userId);
                    deleted++;
                }
            }
            cursor = batch.get(batch.size() - 1).getId();
            if (batch.size() < batchSize) {
                break;
            }
        }
        log.info("messages deleted by thread userId={} threadKey={} count={}", userId, threadKey, deleted);
        return deleted;
    }

    private boolean messageMatchesThreadKey(Message message, String threadKey) {
        try {
            String json = messageCryptoService.decryptIfNeeded(message.getData());
            Map<String, Object> map = objectMapper.readValue(json, MAP_TYPE);
            decryptTextPayload(message.getUserId(), map);
            return matchesThreadKeyFilter(threadKey, map);
        } catch (Exception e) {
            log.warn("message threadKey parse failed id={}: {}", message.getId(), e.getMessage());
            return false;
        }
    }

    public List<Map<String, Object>> getHistory(Long userId, int limit, Long beforeId, String threadKey) {
        List<Map<String, Object>> result = new ArrayList<>();
        Long cursor = beforeId;
        for (int attempt = 0; attempt < 50 && result.size() < limit; attempt++) {
            List<Message> batch;
            var page = org.springframework.data.domain.PageRequest.of(0, limit);
            if (cursor != null && cursor > 0) {
                batch = messageRepository.findByUserIdAndIdLessThanOrderByCreatedAtDesc(userId, cursor, page);
            } else {
                batch = messageRepository.findByUserIdOrderByCreatedAtDesc(userId, page);
            }
            if (batch.isEmpty()) break;
            for (Map<String, Object> m : toMapList(batch)) {
                if (matchesThreadKeyFilter(threadKey, m)) {
                    result.add(m);
                }
            }
            cursor = batch.get(batch.size() - 1).getId();
        }
        return result.size() > limit ? result.subList(0, limit) : result;
    }

    private static boolean matchesThreadKeyFilter(String threadKey, Map<String, Object> m) {
        if (threadKey == null || threadKey.isBlank()) {
            return true;
        }
        Object tk = m.get("threadKey");
        return Objects.equals(threadKey, tk != null ? tk.toString() : null);
    }

    private List<Map<String, Object>> toMapList(List<Message> list) {
        return list.stream()
                .map(m -> {
                    try {
                        String json = messageCryptoService.decryptIfNeeded(m.getData());
                        Map<String, Object> map = objectMapper.readValue(json, MAP_TYPE);
                        decryptTextPayload(m.getUserId(), map);
                        map.put("id", m.getId());
                        return map;
                    } catch (Exception e) {
                        log.warn("message parse failed id={}: {}", m.getId(), e.getMessage());
                        return null;
                    }
                })
                .filter(m -> m != null)
                .filter(m -> {
                    Object type = m.get("type");
                    return type == null || !EPHEMERAL_TYPES.contains(type.toString());
                })
                .collect(Collectors.toList());
    }

    private static Map<String, Object> asStringObjectMap(Map<?, ?> rawMap) {
        Map<String, Object> map = new LinkedHashMap<>();
        rawMap.forEach((key, value) -> map.put(String.valueOf(key), value));
        return map;
    }

    private Map<String, Object> encryptTextPayloadWithUserKey(Long userId, Map<String, Object> envelope) {
        Map<String, Object> copy = new LinkedHashMap<>(envelope);
        if (!isTextEnvelope(copy)) {
            return copy;
        }
        Object payloadObj = copy.get("payload");
        if (!(payloadObj instanceof Map<?, ?> payload)) {
            return copy;
        }
        Map<String, Object> payloadCopy = new LinkedHashMap<>();
        payload.forEach((key, value) -> payloadCopy.put(String.valueOf(key), value));
        Object text = payloadCopy.get("text");
        if (text instanceof String value
                && !userDataEncryption.isUserEncrypted(value)
                && !messageCryptoService.isEncrypted(value)) {
            payloadCopy.put("text", userDataEncryption.encryptForUser(userId, value));
        }
        copy.put("payload", payloadCopy);
        return copy;
    }

    private void decryptTextPayload(Long userId, Map<String, Object> envelope) {
        if (!isTextEnvelope(envelope)) {
            return;
        }
        Object payloadObj = envelope.get("payload");
        if (!(payloadObj instanceof Map<?, ?> payload)) {
            return;
        }
        Object text = payload.get("text");
        if (!(text instanceof String value)) {
            return;
        }
        @SuppressWarnings("unchecked")
        Map<Object, Object> mutablePayload = (Map<Object, Object>) payload;
        if (userDataEncryption.isUserEncrypted(value)) {
            mutablePayload.put("text", userDataEncryption.decryptForUser(userId, value));
        } else if (messageCryptoService.isEncrypted(value)) {
            mutablePayload.put("text", messageCryptoService.decryptIfNeeded(value));
        }
    }

    private static boolean isTextEnvelope(Map<String, Object> envelope) {
        Object type = envelope.get("type");
        return type != null && "text".equals(type.toString());
    }
}
