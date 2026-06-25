package dev.ultrasend.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MembershipMeResponse {
    private String tierCode;
    private String tierName;
    private Integer deviceLimit;
    private Integer addonPacks;
    private Integer currentDeviceCount;
    private Boolean canAddDevice;
    /** {@code true} if the user may create new WebDAV connections (paid tier). */
    private Boolean canAddWebDav;
    private Boolean canBuyAddon;
    /** Overseas subscription period end (epoch millis). */
    private Long subscriptionExpiresAtMs;
    /**
     * Stripe: {@code true} if auto-renew is off (membership ends at {@link #subscriptionExpiresAtMs}).
     * {@code null} if unknown / app-store subscription.
     */
    private Boolean subscriptionCancelAtPeriodEnd;
    /** Overseas Web Stripe subscription linked (manage / upgrade in browser). */
    private Boolean stripeSubscriptionPresent;
    /** Built-in hosted storage monthly upload quota (bytes). Overseas only. */
    private Long hostedUploadQuotaBytes;
    private Long hostedUploadUsedBytes;
    /** e.g. USD */
    private String currency;
    /**
     * Active payment channel: FREE / APPLE_RC / GOOGLE_RC / STRIPE / ALIPAY_LIFETIME.
     * Drives cross-platform channel-affinity UI (where to upgrade / where to manage).
     */
    private String paymentChannel;
    /**
     * {@code true} if the user has no active subscription channel and is free to start in any channel.
     * Equivalent to {@code paymentChannel == null || paymentChannel == FREE}.
     */
    private Boolean canSwitchChannel;
}
