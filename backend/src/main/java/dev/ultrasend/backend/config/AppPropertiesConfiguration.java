package dev.ultrasend.backend.config;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Configuration
@EnableConfigurationProperties({
        AdminProperties.class,
        MessageEncryptionProperties.class,
        StorageS3Properties.class,
        UserDataEncryptionProperties.class
})
public class AppPropertiesConfiguration {
}
