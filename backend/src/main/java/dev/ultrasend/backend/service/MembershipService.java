package dev.ultrasend.backend.service;

import dev.ultrasend.backend.dto.*;
import dev.ultrasend.backend.entity.Device;
import dev.ultrasend.backend.entity.MembershipEntitlement;
import dev.ultrasend.backend.entity.MembershipOrder;
import dev.ultrasend.backend.entity.MembershipOrderEvent;
import dev.ultrasend.backend.entity.User;
import dev.ultrasend.backend.membership.MembershipChannel;
import dev.ultrasend.backend.membership.MembershipOrderStatus;
import dev.ultrasend.backend.membership.MembershipOrderType;
import dev.ultrasend.backend.membership.OverseasMembershipTier;
import dev.ultrasend.backend.membership.MembershipTier;
import dev.ultrasend.backend.membership.RevenueCatDomesticWebhookParser;
import dev.ultrasend.backend.membership.RevenueCatDomesticWebhookParser.Parsed;
import dev.ultrasend.backend.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.env.Environment;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.ArrayList;
import java.util.*;

@Service
@RequiredArgsConstructor
@Slf4j
public class MembershipService {

    private final MembershipEntitlementRepository membershipEntitlementRepository;
    private final MembershipOrderRepository membershipOrderRepository;
    private final MembershipOrderEventRepository membershipOrderEventRepository;
    private final UserRepository userRepository;
    private final DeviceRepository deviceRepository;
    private final AlipayAppPayService alipayAppPayService;
    private final AlipayPagePayService alipayPagePayService;
    private final AlipayWapPayService alipayWapPayService;
    private final Environment environment;
    private final ClusterDeploymentService clusterDeploymentService;
    private final HostedQuotaService hostedQuotaService;
    private final OverseasSubscriptionService overseasSubscriptionService;

    @Value("${app.membership.web-base-url:https://shrimpsend.com}")
    private String webBaseUrl;

    @Value("${app.membership.web-membership-path:/settings/membership}")
    private String webMembershipPath;

    @Value("${app.membership.free-device-limit:3}")
    private Integer freeDeviceLimit;

    @Value("${app.membership.revenuecat.webhook-auth:}")
    private String revenueCatWebhookAuth;

    @Value("${app.membership.rc-product-mini:ultrasend_mini_lifetime}")
    private String rcProductMini;

    @Value("${app.membership.rc-product-pro:ultrasend_pro_lifetime}")
    private String rcProductPro;

    @Value("${app.membership.rc-product-pro-upgrade:ultrasend_mini_to_pro_upgrade}")
    private String rcProductProUpgrade;

    @Value("${app.membership.rc-product-addon-5:ultrasend_addon_5_devices}")
    private String rcProductAddon5;

    @Value("${app.membership.addon-price-cent:4500}")
    private int addonPriceCent;

    @Value("${app.membership.addon-devices:5}")
    private int addonDevices;

    public static final String ADDON_PRODUCT_CODE = "ADDON_5";

    public static final String WEBDAV_MEMBER_ONLY_MESSAGE =
            "WebDAV 为会员功能，请开通会员后再添加连接";

    public List<MembershipTierDto> listTiers() {
        if (clusterDeploymentService.isOverseasDeployment()) {
            return listOverseasTiers();
        }
        List<MembershipTierDto> list = List.of(MembershipTier.PRO).stream()
                .map(v -> MembershipTierDto.builder()
                        .code(v.getCode())
                        .name(v.getDisplayName())
                        .deviceLimit(v.getDeviceLimit())
                        .priceCent(v.getPriceCent())
                        .productType("TIER")
                        .build())
                .toList();
        list = new ArrayList<>(list);
        list.add(MembershipTierDto.builder()
                .code(ADDON_PRODUCT_CODE)
                .name("增购5台设备")
                .deviceLimit(addonDevices)
                .priceCent(addonPriceCent)
                .productType("ADDON")
                .build());
        return list;
    }

    private List<MembershipTierDto> listOverseasTiers() {
        List<MembershipTierDto> rows = new ArrayList<>();
        rows.add(MembershipTierDto.builder().code("PLUS_MONTHLY").name("Plus").deviceLimit(10).priceCent(599).productType("SUBSCRIPTION").billingPeriod("MONTHLY").currency("USD").build());
        rows.add(MembershipTierDto.builder().code("PLUS_YEARLY").name("Plus").deviceLimit(10).priceCent(5969).productType("SUBSCRIPTION").billingPeriod("YEARLY").currency("USD").build());
        rows.add(MembershipTierDto.builder().code("PRO_MONTHLY").name("Pro").deviceLimit(20).priceCent(1199).productType("SUBSCRIPTION").billingPeriod("MONTHLY").currency("USD").build());
        rows.add(MembershipTierDto.builder().code("PRO_YEARLY").name("Pro").deviceLimit(20).priceCent(11939).productType("SUBSCRIPTION").billingPeriod("YEARLY").currency("USD").build());
        rows.add(MembershipTierDto.builder().code("ULTRA_MONTHLY").name("Ultra").deviceLimit(50).priceCent(2499).productType("SUBSCRIPTION").billingPeriod("MONTHLY").currency("USD").build());
        rows.add(MembershipTierDto.builder().code("ULTRA_YEARLY").name("Ultra").deviceLimit(50).priceCent(24890).productType("SUBSCRIPTION").billingPeriod("YEARLY").currency("USD").build());
        return rows;
    }

    public MembershipMeResponse getMyMembership(Long userId) {
        if (clusterDeploymentService.isOverseasDeployment()) {
            OverseasMembershipTier ot = hostedQuotaService.effectiveTier(userId);
            int limit = ot.getDeviceLimit();
            int currentCount = countEffectiveDevicesForLimit(userId);
            String ym = HostedQuotaService.currentYearMonthUtc();
            long used = hostedQuotaService.usedBytes(userId, ym);
            long quota = ot.getMonthlyUploadQuotaBytes();
            var entOpt = membershipEntitlementRepository.findByUserId(userId);
            Long expMs = entOpt
                    .map(e -> e.getSubscriptionExpiresAt() != null ? e.getSubscriptionExpiresAt().toEpochMilli() : null)
                    .orElse(null);
            Boolean cancelAtEnd = entOpt.map(MembershipEntitlement::getSubscriptionCancelAtPeriodEnd).orElse(null);
            boolean stripePresent = entOpt
                    .map(e -> e.getStripeSubscriptionId() != null && !e.getStripeSubscriptionId().isBlank())
                    .orElse(false);
            String paymentChannel = entOpt.map(MembershipEntitlement::getPaymentChannel).orElse("FREE");
            if (paymentChannel == null || paymentChannel.isBlank()) {
                paymentChannel = "FREE";
            }
            boolean canSwitch = "FREE".equals(paymentChannel);
            boolean canAddWebDav = canAddWebDav(userId);
            return MembershipMeResponse.builder()
                    .tierCode(ot.getCode())
                    .tierName(ot.getDisplayName())
                    .deviceLimit(limit)
                    .addonPacks(0)
                    .currentDeviceCount(currentCount)
                    .canAddDevice(currentCount < limit)
                    .canAddWebDav(canAddWebDav)
                    .canBuyAddon(false)
                    .subscriptionExpiresAtMs(expMs)
                    .subscriptionCancelAtPeriodEnd(cancelAtEnd)
                    .stripeSubscriptionPresent(stripePresent)
                    .hostedUploadQuotaBytes(quota)
                    .hostedUploadUsedBytes(used)
                    .currency("USD")
                    .paymentChannel(paymentChannel)
                    .canSwitchChannel(canSwitch)
                    .build();
        }
        MembershipTier tier = getCurrentTier(userId);
        int limit = resolveDeviceLimitForUser(userId);
        int currentCount = countEffectiveDevicesForLimit(userId);
        var entOpt = membershipEntitlementRepository.findByUserId(userId);
        int addonPacks = entOpt
                .map(e -> e.getAddonPacks() != null ? e.getAddonPacks() : 0)
                .orElse(0);
        boolean canBuyAddon = tier == MembershipTier.MINI || tier == MembershipTier.PRO;
        boolean canAddWebDav = canAddWebDav(userId);
        String paymentChannel = entOpt.map(MembershipEntitlement::getPaymentChannel).orElse("FREE");
        if (paymentChannel == null || paymentChannel.isBlank()) {
            paymentChannel = tier == MembershipTier.FREE ? "FREE" : "ALIPAY_LIFETIME";
        }
        return MembershipMeResponse.builder()
                .tierCode(tier.getCode())
                .tierName(tier.getDisplayName())
                .deviceLimit(limit)
                .addonPacks(addonPacks)
                .currentDeviceCount(currentCount)
                .canAddDevice(currentCount < limit)
                .canAddWebDav(canAddWebDav)
                .canBuyAddon(canBuyAddon)
                .paymentChannel(paymentChannel)
                .canSwitchChannel("FREE".equals(paymentChannel))
                .build();
    }

    /**
     * Where should the user go to manage / upgrade? Drives cross-platform UI hints.
     * <ul>
     *   <li>STRIPE → STRIPE_WEB (open Customer Portal / Web settings)</li>
     *   <li>APPLE_RC → APP_STORE (open iOS App Store subscriptions)</li>
     *   <li>GOOGLE_RC → PLAY_STORE</li>
     *   <li>ALIPAY_LIFETIME / FREE → WEB (web membership settings)</li>
     * </ul>
     */
    public CrossPlatformHintResponse getCrossPlatformHint(Long userId) {
        String channel = membershipEntitlementRepository.findByUserId(userId)
                .map(MembershipEntitlement::getPaymentChannel)
                .orElse("FREE");
        if (channel == null || channel.isBlank()) channel = "FREE";

        String webUrl = (webBaseUrl == null ? "" : webBaseUrl) + (webMembershipPath == null ? "" : webMembershipPath);
        String appleUrl = "https://apps.apple.com/account/subscriptions";
        String playUrl = "https://play.google.com/store/account/subscriptions";

        switch (channel) {
            case "STRIPE":
                return CrossPlatformHintResponse.builder()
                        .paymentChannel(channel)
                        .manageTarget("STRIPE_WEB")
                        .webMembershipUrl(webUrl)
                        .messageKey("membership.channelLockedStripe")
                        .build();
            case "APPLE_RC":
                return CrossPlatformHintResponse.builder()
                        .paymentChannel(channel)
                        .manageTarget("APP_STORE")
                        .appleSubscriptionsUrl(appleUrl)
                        .webMembershipUrl(webUrl)
                        .messageKey("membership.channelLockedAppStore")
                        .build();
            case "GOOGLE_RC":
                return CrossPlatformHintResponse.builder()
                        .paymentChannel(channel)
                        .manageTarget("PLAY_STORE")
                        .playSubscriptionsUrl(playUrl)
                        .webMembershipUrl(webUrl)
                        .messageKey("membership.channelLockedPlayStore")
                        .build();
            case "ALIPAY_LIFETIME":
                return CrossPlatformHintResponse.builder()
                        .paymentChannel(channel)
                        .manageTarget("LIFETIME")
                        .webMembershipUrl(webUrl)
                        .messageKey("membership.channelLifetime")
                        .build();
            default:
                return CrossPlatformHintResponse.builder()
                        .paymentChannel("FREE")
                        .manageTarget("FREE")
                        .webMembershipUrl(webUrl)
                        .messageKey("membership.channelFree")
                        .build();
        }
    }

    public MembershipTier getCurrentTier(Long userId) {
        return membershipEntitlementRepository.findByUserId(userId)
                .map(entitlement -> MembershipTier.fromCode(entitlement.getTierCode()))
                .orElse(MembershipTier.FREE);
    }

    public boolean canAddWebDav(Long userId) {
        if (clusterDeploymentService.isOverseasDeployment()) {
            return hostedQuotaService.effectiveTier(userId) != OverseasMembershipTier.FREE;
        }
        return getCurrentTier(userId) != MembershipTier.FREE;
    }

    public void ensureCanAddWebDav(Long userId) {
        if (!canAddWebDav(userId)) {
            throw new IllegalArgumentException(WEBDAV_MEMBER_ONLY_MESSAGE);
        }
    }

    public int resolveDeviceLimitForUser(Long userId) {
        if (clusterDeploymentService.isOverseasDeployment()) {
            return hostedQuotaService.effectiveTier(userId).getDeviceLimit();
        }
        return membershipEntitlementRepository.findByUserId(userId)
                .map(e -> e.getDeviceLimit() != null ? e.getDeviceLimit() : freeDeviceLimit)
                .orElse(freeDeviceLimit);
    }

    /** 与 {@link DeviceService#countEffectiveDevicesForLimit} 一致：非 Web 全计；Web 多条记录统计上仍只占 1 名额。 */
    private int countEffectiveDevicesForLimit(Long userId) {
        List<Device> active = deviceRepository.findAllByUser_IdAndActiveTrue(userId);
        long nonWeb = active.stream()
                .filter(d -> d.getPlatform() == null || !"web".equalsIgnoreCase(d.getPlatform()))
                .count();
        long web = active.stream()
                .filter(d -> d.getPlatform() != null && "web".equalsIgnoreCase(d.getPlatform()))
                .count();
        return (int) (nonWeb + Math.min(1, web));
    }

    @Transactional
    public MembershipCreateOrderResponse createOrder(Long userId, MembershipCreateOrderRequest req) {
        if (clusterDeploymentService.isOverseasDeployment()) {
            throw new IllegalArgumentException("海外集群请使用 App 内购（RevenueCat）或网页 Stripe 订阅");
        }
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("用户不存在"));
        MembershipChannel channel = MembershipChannel.valueOf(req.getChannel().toUpperCase(Locale.ROOT));

        if (ADDON_PRODUCT_CODE.equalsIgnoreCase(req.getTargetTier())) {
            return createAddonOrder(userId, user, channel);
        }

        MembershipTier currentTier = getCurrentTier(userId);
        MembershipTier targetTier = MembershipTier.fromCode(req.getTargetTier());
        if (targetTier == MembershipTier.FREE) {
            throw new IllegalArgumentException("不能购买 FREE 档位");
        }
        if (targetTier == MembershipTier.MINI) {
            throw new IllegalArgumentException("Mini 档位已停售，请购买 Pro");
        }
        if (targetTier == MembershipTier.PRO && currentTier != MembershipTier.FREE) {
            throw new IllegalArgumentException("当前档位不支持购买 Pro 会员，请使用增购扩展设备");
        }
        if (!currentTier.isUpgradableTo(targetTier)) {
            throw new IllegalArgumentException("只能购买更高档位会员");
        }
        int payable = Math.max(0, targetTier.getPriceCent() - currentTier.getPriceCent());
        Instant now = Instant.now();
        MembershipOrder order = MembershipOrder.builder()
                .orderNo(buildOrderNo())
                .user(user)
                .fromTier(currentTier.getCode())
                .toTier(targetTier.getCode())
                .payableAmountCent(payable)
                .currency("CNY")
                .channel(channel.name())
                .orderType(MembershipOrderType.TIER.name())
                .status(channel == MembershipChannel.ALIPAY ? MembershipOrderStatus.PENDING_PAYMENT.name() : MembershipOrderStatus.CREATED.name())
                .createdAt(now)
                .updatedAt(now)
                .build();
        membershipOrderRepository.save(order);
        String payUrl = null;
        String pcPayUrl = null;
        String orderStr = null;
        if (channel == MembershipChannel.ALIPAY) {
            String subject = "虾传 " + targetTier.getDisplayName();
            // 本地环境固定为0.1元（10分）
            int alipayAmountCent = isLocalEnvironment() ? 10 : order.getPayableAmountCent();
            payUrl = alipayWapPayService.createWapPayUrl(order.getOrderNo(), subject, alipayAmountCent);
            orderStr = alipayAppPayService.createOrderString(order.getOrderNo(), subject, alipayAmountCent);
            pcPayUrl = alipayPagePayService.createPagePayUrl(order.getOrderNo(), subject, alipayAmountCent);
            order.setProviderOrderId(order.getOrderNo());
            order.setUpdatedAt(Instant.now());
            membershipOrderRepository.save(order);
        }
        log.info("membership createOrder userId={} orderNo={} from={} to={} amount={} channel={}",
                userId, order.getOrderNo(), currentTier.getCode(), targetTier.getCode(), payable, channel);
        return MembershipCreateOrderResponse.builder()
                .order(toOrderDto(order))
                .alipayPayUrl(payUrl)
                .alipayPcPayUrl(pcPayUrl)
                .alipayOrderString(orderStr)
                .build();
    }

    private MembershipCreateOrderResponse createAddonOrder(Long userId, User user, MembershipChannel channel) {
        MembershipTier currentTier = getCurrentTier(userId);
        if (currentTier != MembershipTier.MINI && currentTier != MembershipTier.PRO) {
            throw new IllegalArgumentException("请先开通 Pro 会员后再增购设备");
        }
        Instant now = Instant.now();
        MembershipOrder order = MembershipOrder.builder()
                .orderNo(buildOrderNo())
                .user(user)
                .fromTier(currentTier.getCode())
                .toTier(currentTier.getCode())
                .payableAmountCent(addonPriceCent)
                .currency("CNY")
                .channel(channel.name())
                .orderType(MembershipOrderType.ADDON.name())
                .status(channel == MembershipChannel.ALIPAY ? MembershipOrderStatus.PENDING_PAYMENT.name() : MembershipOrderStatus.CREATED.name())
                .createdAt(now)
                .updatedAt(now)
                .build();
        membershipOrderRepository.save(order);
        String payUrl = null;
        String pcPayUrl = null;
        String orderStr = null;
        if (channel == MembershipChannel.ALIPAY) {
            // 本地环境固定为0.1元（10分）
            int alipayAmountCent = isLocalEnvironment() ? 10 : order.getPayableAmountCent();
            String subject = "虾传 增购5台设备";
            payUrl = alipayWapPayService.createWapPayUrl(order.getOrderNo(), subject, alipayAmountCent);
            orderStr = alipayAppPayService.createOrderString(order.getOrderNo(), subject, alipayAmountCent);
            pcPayUrl = alipayPagePayService.createPagePayUrl(order.getOrderNo(), subject, alipayAmountCent);
            order.setProviderOrderId(order.getOrderNo());
            order.setUpdatedAt(Instant.now());
            membershipOrderRepository.save(order);
        }
        log.info("membership createAddonOrder userId={} orderNo={} tier={} amount={}", userId, order.getOrderNo(), currentTier.getCode(), addonPriceCent);
        return MembershipCreateOrderResponse.builder()
                .order(toOrderDto(order))
                .alipayPayUrl(payUrl)
                .alipayPcPayUrl(pcPayUrl)
                .alipayOrderString(orderStr)
                .build();
    }

    public MembershipOrderResponse getOrder(Long userId, String orderNo) {
        MembershipOrder order = membershipOrderRepository.findByOrderNo(orderNo)
                .orElseThrow(() -> new IllegalArgumentException("订单不存在"));
        if (!Objects.equals(order.getUser().getId(), userId)) {
            throw new IllegalArgumentException("无权限访问该订单");
        }
        return toOrderDto(order);
    }

    public MembershipAlipayCreateResponse createAlipayPayUrl(Long userId, String orderNo) {
        MembershipOrder order = membershipOrderRepository.findByOrderNo(orderNo)
                .orElseThrow(() -> new IllegalArgumentException("订单不存在"));
        if (!Objects.equals(order.getUser().getId(), userId)) {
            throw new IllegalArgumentException("无权限访问该订单");
        }
        if (!MembershipChannel.ALIPAY.name().equals(order.getChannel())) {
            throw new IllegalArgumentException("该订单不是支付宝订单");
        }
        String subject;
        if (MembershipOrderType.ADDON.name().equals(order.getOrderType())) {
            subject = "虾传 增购5台设备";
        } else {
            subject = "虾传 " + MembershipTier.fromCode(order.getToTier()).getDisplayName();
        }
        int alipayAmountCent = isLocalEnvironment() ? 10 : order.getPayableAmountCent();
        String payUrl = alipayWapPayService.createWapPayUrl(orderNo, subject, alipayAmountCent);
        return MembershipAlipayCreateResponse.builder()
                .orderNo(orderNo)
                .payUrl(payUrl)
                .build();
    }

    @Transactional
    public boolean processAlipayPaid(String orderNo, String tradeNo, int totalAmountCent, String payload) {
        MembershipOrder order = membershipOrderRepository.findByOrderNo(orderNo)
                .orElseThrow(() -> new IllegalArgumentException("订单不存在"));
        log.info(
                "alipay paid processing orderNo={} tradeNo={} totalAmountCent={} orderPayableCent={} orderStatus={}",
                orderNo,
                tradeNo,
                totalAmountCent,
                order.getPayableAmountCent(),
                order.getStatus());
        // 本地环境下，支付宝支付金额固定为0.1元（10分），但订单记录中的金额是原始金额
        // 所以需要特殊处理：如果支付金额是10分且是本地环境，则接受
        if (isLocalEnvironment() && totalAmountCent == 10) {
            // 本地环境支付0.1元，接受
            log.info("local environment: accepting 0.1 yuan payment for orderNo={}, original amount={}", orderNo, order.getPayableAmountCent());
        } else if (totalAmountCent != order.getPayableAmountCent()) {
            throw new IllegalArgumentException("支付金额不匹配");
        } else {
            log.info("alipay paid amount verified orderNo={} amountCent={}", orderNo, totalAmountCent);
        }
        String eventKey = "ALIPAY:" + tradeNo;
        if (membershipOrderEventRepository.existsByProviderAndEventUniqueKey("ALIPAY", eventKey)) {
            log.info("alipay notify duplicated orderNo={} tradeNo={} eventKey={}", orderNo, tradeNo, eventKey);
            return false;
        }
        log.info("alipay paid saving event orderNo={} tradeNo={} eventKey={}", orderNo, tradeNo, eventKey);
        membershipOrderEventRepository.save(MembershipOrderEvent.builder()
                .provider("ALIPAY")
                .eventType("PAID")
                .eventUniqueKey(eventKey)
                .orderNo(orderNo)
                .payload(payload)
                .createdAt(Instant.now())
                .build());
        grantEntitlementFromOrder(order, tradeNo, payload);
        log.info("alipay paid result=granted orderNo={} tradeNo={}", orderNo, tradeNo);
        return true;
    }

    @Transactional
    public boolean processRevenueCatWebhook(Map<String, Object> payload, String authorizationHeader) {
        validateRevenueCatAuth(authorizationHeader);
        if (clusterDeploymentService.isOverseasDeployment()) {
            return overseasSubscriptionService.processRevenueCatPayload(payload);
        }
        Parsed rc = RevenueCatDomesticWebhookParser.parse(payload);
        String transactionId = rc.transactionId();
        String productId = rc.productId();
        String appUserId = rc.appUserId();
        String eventType = rc.eventType();
        log.info(
                "revenuecat domestic processing appUserId={} transactionId={} productId={} eventType={}",
                appUserId,
                transactionId,
                productId,
                eventType);
        if (appUserId == null || appUserId.isBlank()) {
            throw new IllegalArgumentException("app_user_id 为空");
        }
        if (transactionId == null || transactionId.isBlank()) {
            throw new IllegalArgumentException("transaction_id 为空");
        }
        Long userId;
        try {
            userId = Long.parseLong(appUserId);
        } catch (NumberFormatException ex) {
            throw new IllegalArgumentException("app_user_id 非法");
        }

        String eventKey = "RC:" + transactionId + ":" + productId;
        if (membershipOrderEventRepository.existsByProviderAndEventUniqueKey("REVENUECAT", eventKey)) {
            log.info("revenuecat duplicated userId={} transactionId={} productId={} eventKey={}",
                    userId, transactionId, productId, eventKey);
            return false;
        }
        String payloadRaw = payload.toString();
        membershipOrderEventRepository.save(MembershipOrderEvent.builder()
                .provider("REVENUECAT")
                .eventType(eventType == null ? "UNKNOWN" : eventType)
                .eventUniqueKey(eventKey)
                .payload(payloadRaw)
                .createdAt(Instant.now())
                .build());

        if (rcProductAddon5.equals(productId)) {
            MembershipOrder addonOrder = createAddonOrderForRc(userId);
            log.info("revenuecat domestic granting addon userId={} orderNo={}", userId, addonOrder.getOrderNo());
            grantEntitlementFromOrder(addonOrder, transactionId, payloadRaw);
        } else {
            MembershipTier targetTier = mapRcProductToTier(productId);
            MembershipOrder order = createOrFindAppleOrder(userId, targetTier);
            log.info("revenuecat domestic granting tier userId={} orderNo={} targetTier={}",
                    userId, order.getOrderNo(), targetTier.getCode());
            grantEntitlementFromOrder(order, transactionId, payloadRaw);
        }
        return true;
    }

    private void validateRevenueCatAuth(String authorizationHeader) {
        if (revenueCatWebhookAuth == null || revenueCatWebhookAuth.isBlank()) {
            return;
        }
        String expected = "Bearer " + revenueCatWebhookAuth.trim();
        if (!expected.equals(authorizationHeader)) {
            throw new IllegalArgumentException("RevenueCat webhook 鉴权失败");
        }
    }

    /**
     * RC webhook 专用：创建 Apple 买断/升级订单记录。
     * {@code rc-product-pro-upgrade} 为存量 Mini→Pro 升级包（客户端已停售，仅 webhook 兼容）。
     */
    private MembershipOrder createOrFindAppleOrder(Long userId, MembershipTier targetTier) {
        Optional<MembershipOrder> existing = membershipOrderRepository
                .findTopByUserIdAndToTierAndChannelAndStatusOrderByCreatedAtDesc(
                        userId,
                        targetTier.getCode(),
                        MembershipChannel.APPLE_RC.name(),
                        MembershipOrderStatus.CREATED.name()
                );
        if (existing.isPresent()) {
            return existing.get();
        }
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("用户不存在"));
        MembershipTier currentTier = getCurrentTier(userId);
        if (!currentTier.isUpgradableTo(targetTier)) {
            throw new IllegalArgumentException("当前档位不需要重复购买");
        }
        int payable = Math.max(0, targetTier.getPriceCent() - currentTier.getPriceCent());
        MembershipOrder order = MembershipOrder.builder()
                .orderNo(buildOrderNo())
                .user(user)
                .fromTier(currentTier.getCode())
                .toTier(targetTier.getCode())
                .payableAmountCent(payable)
                .currency("CNY")
                .channel(MembershipChannel.APPLE_RC.name())
                .orderType(MembershipOrderType.TIER.name())
                .status(MembershipOrderStatus.CREATED.name())
                .createdAt(Instant.now())
                .updatedAt(Instant.now())
                .build();
        return membershipOrderRepository.save(order);
    }

    private MembershipOrder createAddonOrderForRc(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("用户不存在"));
        MembershipTier currentTier = getCurrentTier(userId);
        if (currentTier != MembershipTier.MINI && currentTier != MembershipTier.PRO) {
            throw new IllegalArgumentException("请先开通 Pro 会员后再增购设备");
        }
        return membershipOrderRepository.save(MembershipOrder.builder()
                .orderNo(buildOrderNo())
                .user(user)
                .fromTier(currentTier.getCode())
                .toTier(currentTier.getCode())
                .payableAmountCent(addonPriceCent)
                .currency("CNY")
                .channel(MembershipChannel.APPLE_RC.name())
                .orderType(MembershipOrderType.ADDON.name())
                .status(MembershipOrderStatus.CREATED.name())
                .createdAt(Instant.now())
                .updatedAt(Instant.now())
                .build());
    }

    private void grantEntitlementFromOrder(MembershipOrder order, String providerTradeId, String payload) {
        if (MembershipOrderStatus.GRANTED.name().equals(order.getStatus())) {
            return;
        }
        order.setStatus(MembershipOrderStatus.PAID.name());
        order.setProviderTradeId(providerTradeId);
        order.setProviderPayload(payload);
        order.setPaidAt(Instant.now());
        order.setUpdatedAt(Instant.now());
        membershipOrderRepository.save(order);

        MembershipEntitlement entitlement = membershipEntitlementRepository.findByUserId(order.getUser().getId())
                .orElse(MembershipEntitlement.builder()
                        .user(order.getUser())
                        .tierCode(MembershipTier.FREE.getCode())
                        .deviceLimit(freeDeviceLimit)
                        .addonPacks(0)
                        .isLifetime(true)
                        .effectiveAt(Instant.now())
                        .updatedAt(Instant.now())
                        .build());

        if (MembershipOrderType.ADDON.name().equals(order.getOrderType())) {
            int prev = entitlement.getAddonPacks() != null ? entitlement.getAddonPacks() : 0;
            entitlement.setAddonPacks(prev + 1);
            entitlement.setDeviceLimit((entitlement.getDeviceLimit() != null ? entitlement.getDeviceLimit() : freeDeviceLimit) + addonDevices);
        } else {
            MembershipTier target = MembershipTier.fromCode(order.getToTier());
            MembershipTier current = MembershipTier.fromCode(entitlement.getTierCode());
            if (current.getRank() < target.getRank()) {
                entitlement.setTierCode(target.getCode());
                int addon = entitlement.getAddonPacks() != null ? entitlement.getAddonPacks() : 0;
                entitlement.setDeviceLimit(target.getDeviceLimit() + addon * addonDevices);
                entitlement.setIsLifetime(true);
                entitlement.setEffectiveAt(Instant.now());
            }
        }
        // Mainland (lifetime) entitlements: tag with ALIPAY_LIFETIME (Alipay one-shot) or
        // APPLE_RC (iOS lifetime IAP). Used by cross-platform channel-affinity logic.
        if (entitlement.getPaymentChannel() == null
                || "FREE".equals(entitlement.getPaymentChannel())) {
            String channel = order.getChannel();
            if (MembershipChannel.ALIPAY.name().equals(channel)) {
                entitlement.setPaymentChannel(MembershipChannel.ALIPAY_LIFETIME.name());
            } else if (MembershipChannel.APPLE_RC.name().equals(channel)) {
                entitlement.setPaymentChannel(MembershipChannel.APPLE_RC.name());
            }
        }
        entitlement.setUpdatedAt(Instant.now());
        membershipEntitlementRepository.save(entitlement);

        order.setStatus(MembershipOrderStatus.GRANTED.name());
        order.setGrantedAt(Instant.now());
        order.setUpdatedAt(Instant.now());
        membershipOrderRepository.save(order);
        log.info("membership granted userId={} orderType={} from={} to={} orderNo={}",
                order.getUser().getId(), order.getOrderType(), order.getFromTier(), order.getToTier(), order.getOrderNo());
    }

    private MembershipTier mapRcProductToTier(String productId) {
        if (productId == null || productId.isBlank()) {
            throw new IllegalArgumentException("product_id 为空");
        }
        Map<String, MembershipTier> mapping = Map.of(
                rcProductMini, MembershipTier.MINI,
                rcProductPro, MembershipTier.PRO,
                rcProductProUpgrade, MembershipTier.PRO
        );
        MembershipTier tier = mapping.get(productId);
        if (tier == null) {
            throw new IllegalArgumentException("未知 RevenueCat 商品: " + productId);
        }
        return tier;
    }

    private String asString(Object v) {
        return v == null ? null : String.valueOf(v);
    }

    private String buildOrderNo() {
        return "M" + System.currentTimeMillis() + UUID.randomUUID().toString().replace("-", "").substring(0, 8).toUpperCase(Locale.ROOT);
    }

    /**
     * 判断是否是本地环境（非生产环境）
     * 通过检查 spring.profiles.active 是否包含 "prod" 来判断
     */
    private boolean isLocalEnvironment() {
        String[] activeProfiles = environment.getActiveProfiles();
        for (String profile : activeProfiles) {
            if ("prod".equals(profile)) {
                return false;
            }
        }
        return true;
    }

    @Transactional
    @Scheduled(fixedDelayString = "${app.membership.reconcile-delay-ms:300000}")
    public void reconcilePaidOrders() {
        List<MembershipOrder> paidOrders = membershipOrderRepository.findAllByStatus(MembershipOrderStatus.PAID.name());
        if (paidOrders.isEmpty()) {
            return;
        }
        for (MembershipOrder order : paidOrders) {
            try {
                grantEntitlementFromOrder(order, order.getProviderTradeId(), order.getProviderPayload());
            } catch (Exception e) {
                log.warn("reconcile paid order failed orderNo={} reason={}", order.getOrderNo(), e.getMessage());
            }
        }
    }

    private MembershipOrderResponse toOrderDto(MembershipOrder order) {
        return MembershipOrderResponse.builder()
                .orderNo(order.getOrderNo())
                .fromTier(order.getFromTier())
                .toTier(order.getToTier())
                .payableAmountCent(order.getPayableAmountCent())
                .currency(order.getCurrency())
                .channel(order.getChannel())
                .status(order.getStatus())
                .createdAt(order.getCreatedAt() == null ? null : order.getCreatedAt().toEpochMilli())
                .updatedAt(order.getUpdatedAt() == null ? null : order.getUpdatedAt().toEpochMilli())
                .build();
    }
}
