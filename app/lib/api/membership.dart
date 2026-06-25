import 'dart:convert';
import 'package:http/http.dart' as http;
import '../logger.dart';
import 'client.dart';

class MembershipTier {
  final String code;
  final String name;
  final int deviceLimit;
  final int priceCent;
  final String productType;
  final String? billingPeriod;
  final String? currency;

  MembershipTier({
    required this.code,
    required this.name,
    required this.deviceLimit,
    required this.priceCent,
    this.productType = 'TIER',
    this.billingPeriod,
    this.currency,
  });

  factory MembershipTier.fromJson(Map<String, dynamic> j) => MembershipTier(
        code: (j['code'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        deviceLimit: (j['deviceLimit'] as num?)?.toInt() ?? 0,
        priceCent: (j['priceCent'] as num?)?.toInt() ?? 0,
        productType: (j['productType'] ?? 'TIER').toString(),
        billingPeriod: j['billingPeriod']?.toString(),
        currency: j['currency']?.toString(),
      );

  bool get isAddon => productType == 'ADDON';
}

const String addonProductCode = 'ADDON_5';

class MembershipMe {
  final String tierCode;
  final String tierName;
  final int deviceLimit;
  final int addonPacks;
  final int currentDeviceCount;
  final bool canAddDevice;
  final bool canAddWebDav;
  final bool canBuyAddon;
  final int? subscriptionExpiresAtMs;
  final bool? subscriptionCancelAtPeriodEnd;
  final bool? stripeSubscriptionPresent;
  final int? hostedUploadQuotaBytes;
  final int? hostedUploadUsedBytes;
  final String? currency;

  /// 当前活跃支付渠道: FREE / APPLE_RC / GOOGLE_RC / STRIPE / ALIPAY_LIFETIME
  final String paymentChannel;

  /// true 表示当前用户无活跃订阅、可自由选择任一渠道。
  final bool canSwitchChannel;

  MembershipMe({
    required this.tierCode,
    required this.tierName,
    required this.deviceLimit,
    this.addonPacks = 0,
    required this.currentDeviceCount,
    required this.canAddDevice,
    this.canAddWebDav = false,
    this.canBuyAddon = false,
    this.subscriptionExpiresAtMs,
    this.subscriptionCancelAtPeriodEnd,
    this.stripeSubscriptionPresent,
    this.hostedUploadQuotaBytes,
    this.hostedUploadUsedBytes,
    this.currency,
    this.paymentChannel = 'FREE',
    this.canSwitchChannel = true,
  });

  factory MembershipMe.fromJson(Map<String, dynamic> j) {
    final channel = (j['paymentChannel'] as String?)?.trim();
    return MembershipMe(
      tierCode: (j['tierCode'] ?? 'FREE').toString(),
      tierName: (j['tierName'] ?? 'Free').toString(),
      deviceLimit: (j['deviceLimit'] as num?)?.toInt() ?? 0,
      addonPacks: (j['addonPacks'] as num?)?.toInt() ?? 0,
      currentDeviceCount: (j['currentDeviceCount'] as num?)?.toInt() ?? 0,
      canAddDevice: j['canAddDevice'] == true,
      canAddWebDav: j['canAddWebDav'] == true,
      canBuyAddon: j['canBuyAddon'] == true,
      subscriptionExpiresAtMs: (j['subscriptionExpiresAtMs'] as num?)?.toInt(),
      subscriptionCancelAtPeriodEnd: j['subscriptionCancelAtPeriodEnd'] as bool?,
      stripeSubscriptionPresent: j['stripeSubscriptionPresent'] as bool?,
      hostedUploadQuotaBytes: (j['hostedUploadQuotaBytes'] as num?)?.toInt(),
      hostedUploadUsedBytes: (j['hostedUploadUsedBytes'] as num?)?.toInt(),
      currency: j['currency']?.toString(),
      paymentChannel: channel == null || channel.isEmpty ? 'FREE' : channel,
      canSwitchChannel:
          j['canSwitchChannel'] as bool? ?? (channel == null || channel.isEmpty || channel == 'FREE'),
    );
  }
}

class CrossPlatformHint {
  final String paymentChannel;
  final String manageTarget;
  final String? manageUrl;
  final String? webMembershipUrl;
  final String? appleSubscriptionsUrl;
  final String? playSubscriptionsUrl;
  final String? messageKey;

  CrossPlatformHint({
    required this.paymentChannel,
    required this.manageTarget,
    this.manageUrl,
    this.webMembershipUrl,
    this.appleSubscriptionsUrl,
    this.playSubscriptionsUrl,
    this.messageKey,
  });

  factory CrossPlatformHint.fromJson(Map<String, dynamic> j) => CrossPlatformHint(
        paymentChannel: (j['paymentChannel'] ?? 'FREE').toString(),
        manageTarget: (j['manageTarget'] ?? 'WEB').toString(),
        manageUrl: j['manageUrl'] as String?,
        webMembershipUrl: j['webMembershipUrl'] as String?,
        appleSubscriptionsUrl: j['appleSubscriptionsUrl'] as String?,
        playSubscriptionsUrl: j['playSubscriptionsUrl'] as String?,
        messageKey: j['messageKey'] as String?,
      );
}

class MembershipOrder {
  final String orderNo;
  final String fromTier;
  final String toTier;
  final int payableAmountCent;
  final String currency;
  final String channel;
  final String status;

  MembershipOrder({
    required this.orderNo,
    required this.fromTier,
    required this.toTier,
    required this.payableAmountCent,
    required this.currency,
    required this.channel,
    required this.status,
  });

  factory MembershipOrder.fromJson(Map<String, dynamic> j) => MembershipOrder(
        orderNo: (j['orderNo'] ?? '').toString(),
        fromTier: (j['fromTier'] ?? '').toString(),
        toTier: (j['toTier'] ?? '').toString(),
        payableAmountCent: (j['payableAmountCent'] as num?)?.toInt() ?? 0,
        currency: (j['currency'] ?? 'CNY').toString(),
        channel: (j['channel'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
      );
}

class MembershipCreateOrderResponse {
  final MembershipOrder order;

  /// 支付宝 WAP 手机网页支付链接（手机浏览器使用）
  final String? alipayPayUrl;

  /// 支付宝 PC 网页支付链接（桌面端外部浏览器使用，AlipayTradePagePay）
  final String? alipayPcPayUrl;

  /// APP 支付订单字符串，供 Tobias 调起支付宝（有则优先使用，否则用 alipayPayUrl）
  final String? alipayOrderString;

  MembershipCreateOrderResponse({
    required this.order,
    this.alipayPayUrl,
    this.alipayPcPayUrl,
    this.alipayOrderString,
  });

  factory MembershipCreateOrderResponse.fromJson(Map<String, dynamic> j) =>
      MembershipCreateOrderResponse(
        order: MembershipOrder.fromJson(j['order'] as Map<String, dynamic>),
        alipayPayUrl: j['alipayPayUrl'] as String?,
        alipayPcPayUrl: j['alipayPcPayUrl'] as String?,
        alipayOrderString: j['alipayOrderString'] as String?,
      );
}

Future<List<MembershipTier>> listMembershipTiers() async {
  return withAuthRetry(() async {
    final r = await http.get(
      Uri.parse('$apiBaseUrl/api/membership/tiers'),
      headers: apiHeaders,
    );
    checkAuthResponse(r, fallback: '获取会员档位失败');
    final list = (jsonDecode(r.body) as List)
        .map((e) => MembershipTier.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  });
}

Future<MembershipMe> fetchMyMembership() async {
  return withAuthRetry(() async {
    final r = await http.get(
      Uri.parse('$apiBaseUrl/api/membership/me'),
      headers: apiHeaders,
    );
    checkAuthResponse(r, fallback: '获取会员状态失败');
    return MembershipMe.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  });
}

Future<MembershipCreateOrderResponse> createMembershipOrder({
  required String targetTier,
  required String channel,
}) async {
  logApi.info('createMembershipOrder targetTier=$targetTier channel=$channel');
  return withAuthRetry(() async {
    final r = await http.post(
      Uri.parse('$apiBaseUrl/api/membership/orders'),
      headers: apiHeaders,
      body: jsonEncode({'targetTier': targetTier, 'channel': channel}),
    );
    checkAuthResponse(r, fallback: '创建会员订单失败');
    return MembershipCreateOrderResponse.fromJson(
      jsonDecode(r.body) as Map<String, dynamic>,
    );
  });
}

Future<MembershipOrder> getMembershipOrder(String orderNo) async {
  return withAuthRetry(() async {
    final r = await http.get(
      Uri.parse('$apiBaseUrl/api/membership/orders/${Uri.encodeComponent(orderNo)}'),
      headers: apiHeaders,
    );
    checkAuthResponse(r, fallback: '查询订单失败');
    return MembershipOrder.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  });
}

class MembershipMigrationVerifyResponse {
  final bool success;
  final String message;
  final String? tierCode;
  final String? tierName;
  final int? deviceLimit;

  MembershipMigrationVerifyResponse({
    required this.success,
    required this.message,
    this.tierCode,
    this.tierName,
    this.deviceLimit,
  });

  factory MembershipMigrationVerifyResponse.fromJson(Map<String, dynamic> j) =>
      MembershipMigrationVerifyResponse(
        success: j['success'] == true,
        message: (j['message'] ?? '').toString(),
        tierCode: j['tierCode'] as String?,
        tierName: j['tierName'] as String?,
        deviceLimit: (j['deviceLimit'] as num?)?.toInt(),
      );
}

Future<void> sendMembershipMigrationCode(String mobile) async {
  logApi.info('sendMembershipMigrationCode mobile=$mobile');
  return withAuthRetry(() async {
    final r = await http.post(
      Uri.parse('$apiBaseUrl/api/membership/migration/send-code'),
      headers: apiHeaders,
      body: jsonEncode({'mobile': mobile}),
    );
    checkAuthResponse(r, fallback: '发送验证码失败');
  });
}

Future<MembershipMigrationVerifyResponse> verifyMembershipMigration({
  required String mobile,
  required String code,
}) async {
  logApi.info('verifyMembershipMigration mobile=$mobile');
  return withAuthRetry(() async {
    final r = await http.post(
      Uri.parse('$apiBaseUrl/api/membership/migration/verify'),
      headers: apiHeaders,
      body: jsonEncode({'mobile': mobile, 'code': code}),
    );
    checkAuthResponse(r, fallback: '验证失败');
    return MembershipMigrationVerifyResponse.fromJson(
      jsonDecode(r.body) as Map<String, dynamic>,
    );
  });
}

Future<MembershipMigrationVerifyResponse> grantMembershipMigration({
  required String mobile,
}) async {
  logApi.info('grantMembershipMigration mobile=$mobile');
  return withAuthRetry(() async {
    final r = await http.post(
      Uri.parse('$apiBaseUrl/api/membership/migration/grant'),
      headers: apiHeaders,
      body: jsonEncode({'mobile': mobile}),
    );
    checkAuthResponse(r, fallback: '授予会员失败');
    return MembershipMigrationVerifyResponse.fromJson(
      jsonDecode(r.body) as Map<String, dynamic>,
    );
  });
}

/// 创建 Stripe Checkout Session（海外集群）。返回 Stripe 托管支付页面 URL。
///
/// [platform] 用于在 success_url 中标记来源，便于浏览器页面区分桌面 vs Web 用户并展示
/// 「已付款，请回到 App」之类的提示。
Future<String> createStripeCheckoutSession({
  required String priceId,
  String platform = 'desktop',
}) async {
  logApi.info('createStripeCheckoutSession priceId=$priceId platform=$platform');
  return withAuthRetry(() async {
    final r = await http.post(
      Uri.parse('$apiBaseUrl/api/membership/stripe/create-checkout-session'),
      headers: apiHeaders,
      body: jsonEncode({'priceId': priceId, 'platform': platform}),
    );
    checkAuthResponse(r, fallback: '创建 Stripe 订阅会话失败');
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return (j['url'] ?? '').toString();
  });
}

Future<String> createStripeBillingPortalSession() async {
  return withAuthRetry(() async {
    final r = await http.post(
      Uri.parse('$apiBaseUrl/api/membership/stripe/billing-portal-session'),
      headers: apiHeaders,
      body: '',
    );
    checkAuthResponse(r, fallback: '打开 Stripe 订阅管理失败');
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return (j['url'] ?? '').toString();
  });
}

Future<void> updateStripeSubscriptionPrice(String priceId) async {
  logApi.info('updateStripeSubscriptionPrice priceId=$priceId');
  return withAuthRetry(() async {
    final r = await http.post(
      Uri.parse('$apiBaseUrl/api/membership/stripe/subscription/update-price'),
      headers: apiHeaders,
      body: jsonEncode({'priceId': priceId}),
    );
    checkAuthResponse(r, fallback: '升级 Stripe 订阅失败');
  });
}

Future<CrossPlatformHint> fetchCrossPlatformHint() async {
  return withAuthRetry(() async {
    final r = await http.get(
      Uri.parse('$apiBaseUrl/api/membership/cross-platform-hint'),
      headers: apiHeaders,
    );
    checkAuthResponse(r, fallback: '获取跨平台引导失败');
    return CrossPlatformHint.fromJson(
      jsonDecode(r.body) as Map<String, dynamic>,
    );
  });
}
