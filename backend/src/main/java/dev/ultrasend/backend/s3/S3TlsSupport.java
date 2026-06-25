package dev.ultrasend.backend.s3;

import javax.net.ssl.TrustManager;
import javax.net.ssl.TrustManagerFactory;
import java.io.InputStream;
import java.net.URI;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyStore;
import java.security.cert.Certificate;
import java.security.cert.CertificateFactory;
import java.util.Locale;

/**
 * Supplemental TLS trust for S3 endpoints whose servers omit intermediate CAs
 * (e.g. CSTCloud Data Capsule {@code *.cstcloud.cn} signed by CFCA, absent from JVM cacerts).
 */
public final class S3TlsSupport {

    private static final String INTERMEDIATE_PEM = "/tls/cfca-tls-ov-oca.pem";
    private static final String ROOT_PEM = "/tls/cfca-ev-root.pem";
    private static final String DEFAULT_CACERTS_PASSWORD = "changeit";

    private static volatile TrustManager[] cstcloudTrustManagers;

    private S3TlsSupport() {
    }

    public static boolean needsSupplementalTrust(String endpoint) {
        if (endpoint == null || endpoint.isBlank()) {
            return false;
        }
        try {
            String host = URI.create(endpoint.trim()).getHost();
            return host != null && host.toLowerCase(Locale.ROOT).endsWith("cstcloud.cn");
        } catch (Exception ignored) {
            return false;
        }
    }

    /**
     * Returns merged JVM + CFCA trust managers for {@code *.cstcloud.cn}, or {@code null} to use SDK defaults.
     */
    public static TrustManager[] trustManagersFor(String endpoint) {
        if (!needsSupplementalTrust(endpoint)) {
            return null;
        }
        TrustManager[] cached = cstcloudTrustManagers;
        if (cached != null) {
            return cached;
        }
        synchronized (S3TlsSupport.class) {
            if (cstcloudTrustManagers == null) {
                cstcloudTrustManagers = buildMergedTrustManagers();
            }
            return cstcloudTrustManagers;
        }
    }

    public static boolean isSslProbeError(String message, Throwable cause) {
        if (containsSslHint(message)) {
            return true;
        }
        Throwable current = cause;
        while (current != null) {
            if (containsSslHint(current.getMessage())) {
                return true;
            }
            current = current.getCause();
        }
        return false;
    }

    private static boolean containsSslHint(String message) {
        if (message == null || message.isBlank()) {
            return false;
        }
        String lower = message.toLowerCase(Locale.ROOT);
        return lower.contains("pkix")
                || lower.contains("certpath")
                || lower.contains("certificate")
                || lower.contains("ssl")
                || lower.contains("tls")
                || lower.contains("handshake");
    }

    private static TrustManager[] buildMergedTrustManagers() {
        try {
            KeyStore merged = loadDefaultKeyStore();
            addPemCertificate(merged, "cfca-tls-ov-oca", INTERMEDIATE_PEM);
            addPemCertificate(merged, "cfca-ev-root", ROOT_PEM);
            TrustManagerFactory tmf = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
            tmf.init(merged);
            return tmf.getTrustManagers();
        } catch (Exception e) {
            throw new IllegalStateException("Failed to build CFCA supplemental trust store", e);
        }
    }

    private static KeyStore loadDefaultKeyStore() throws Exception {
        KeyStore ks = KeyStore.getInstance(KeyStore.getDefaultType());
        Path cacerts = Path.of(System.getProperty("java.home"), "lib", "security", "cacerts");
        try (InputStream in = Files.newInputStream(cacerts)) {
            ks.load(in, DEFAULT_CACERTS_PASSWORD.toCharArray());
        }
        return ks;
    }

    private static void addPemCertificate(KeyStore ks, String alias, String resourcePath) throws Exception {
        try (InputStream in = S3TlsSupport.class.getResourceAsStream(resourcePath)) {
            if (in == null) {
                throw new IllegalStateException("Missing classpath resource: " + resourcePath);
            }
            CertificateFactory cf = CertificateFactory.getInstance("X.509");
            Certificate cert = cf.generateCertificate(in);
            ks.setCertificateEntry(alias, cert);
        }
    }
}
