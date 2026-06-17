import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tobias/tobias.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api.dart';
import '../config/env.dart';
import '../l10n/generated/app_localizations.dart';
import '../preferences/service_region.dart';
import '../services/membership_channel_guard.dart';
import '../services/revenuecat_service.dart';
import '../services/analytics/analytics.dart';
import '../services/analytics/analytics_events.dart';
import '../ui/app_ui.dart';
import '../utils/auth_route_guard.dart';
import '../utils/mainland_membership_purchase.dart';
import '../utils/membership_overseas_catalog.dart';
import '../utils/runtime_platform.dart';
import '../utils/toast.dart';
import 'membership_migration_screen.dart';

String _subscriptionScheduleLine(BuildContext context, MembershipMe me) {
  final l10n = AppLocalizations.of(context);
  final ms = me.subscriptionExpiresAtMs!;
  final locale = Localizations.localeOf(context).toString();
  final dateStr = DateFormat.yMMMd(locale).add_jm().format(DateTime.fromMillisecondsSinceEpoch(ms));
  if (me.subscriptionCancelAtPeriodEnd == true) {
    return l10n.membershipSubscriptionEndsAfterCancel(dateStr);
  }
  if (me.subscriptionCancelAtPeriodEnd == false) {
    return l10n.membershipSubscriptionRenewsAt(dateStr);
  }
  return l10n.membershipSubscriptionValidUntil(dateStr);
}

class MembershipScreen extends ConsumerStatefulWidget {
  const MembershipScreen({super.key});

  @override
  ConsumerState<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends ConsumerState<MembershipScreen> {
  bool _loading = true;
  List<MembershipTier> _tiers = const [];
  MembershipMe? _me;
  String? _pendingOrderNo;
  Timer? _pollTimer;
  DateTime? _pollStartedAt;
  bool _purchasingApple = false;
  bool _restoringPurchases = false;
  bool _openingStripe = false;
  OverseasBilling _overseasBilling = OverseasBilling.yearly;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ensureLoggedInForRoute(context, ref)) return;
      _load();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([listMembershipTiers(), fetchMyMembership()]);
      if (!mounted) return;
      setState(() {
        _tiers = results[0] as List<MembershipTier>;
        _me = results[1] as MembershipMe;
        _loading = false;
      });
      Analytics.track(AnalyticsEvents.membershipScreenView, {
        'tier_count': _tiers.length,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.show(
        context,
        message: AppLocalizations.of(context).membershipLoadFailed('$e'),
      );
    }
  }

  Future<void> _buy(MembershipTier tier) async {
    final l10n = AppLocalizations.of(context);
    final overseasCtx = isOverseasAppContext(_tiers);

    if (tier.isAddon && !(_me?.canBuyAddon ?? false)) {
      AppToast.show(context, message: l10n.membershipBuyMiniOrProFirst);
      return;
    }

    if (!overseasCtx &&
        tier.productType == 'TIER' &&
        isMainlandTierPurchaseDisabled(
          tier,
          _me,
          pendingOrder: _pendingOrderNo != null,
          purchasing: _purchasingApple || _openingStripe || _restoringPurchases,
        )) {
      return;
    }

    // Cross-platform channel-affinity guard: if the user is already locked into a
    // specific channel (Stripe / Apple / Google), route them there instead of letting
    // a second channel double-charge.
    final surface = _resolvePurchaseSurface(tier);
    final decision =
        decideMembershipPurchase(me: _me, surface: surface, isAddon: tier.isAddon);
    if (!decision.canPurchase) {
      await _handleChannelLocked(decision);
      return;
    }

    Analytics.track(AnalyticsEvents.membershipPurchaseStart, {
      'tier_code': tier.code,
      'channel': _resolvePurchaseSurface(tier).name,
    });

    // Desktop: no native IAP — open the appropriate web payment in the browser.
    if (RuntimePlatform.isDesktop) {
      if (overseasCtx && tier.productType == 'SUBSCRIPTION') {
        await _buyOverseasStripe(tier, isUpgrade: _isOverseasUpgrade(tier));
        return;
      }
      if (Env.prodServiceRegion == ServiceRegion.international) {
        AppToast.show(
          context,
          message: overseasCtx
              ? l10n.membershipStripePriceMissing
              : l10n.membershipOverseasNoAlipay,
        );
        return;
      }
      if (!overseasCtx) {
        await _buyMainlandAlipayDesktop(tier);
        return;
      }
    }

    final overseasStore = Env.prodServiceRegion == ServiceRegion.international &&
        RevenueCatService.instance.canUseOverseasStorePurchase &&
        tier.productType == 'SUBSCRIPTION';
    final useApple = Platform.isIOS && RevenueCatService.instance.canUseApplePurchase && !overseasStore;
    if (overseasStore && tier.productType == 'SUBSCRIPTION') {
      try {
        setState(() => _purchasingApple = true);
        final ok = await RevenueCatService.instance.purchaseTier(tier.code);
        if (!mounted) return;
        setState(() => _purchasingApple = false);
        if (ok) {
          await _onRcPurchaseSuccess(tier.code);
          Analytics.track(AnalyticsEvents.membershipPurchaseOutcome, {
            'tier_code': tier.code,
            'channel': 'revenuecat',
            'status': 'success',
          });
        } else {
          Analytics.track(AnalyticsEvents.membershipPurchaseOutcome, {
            'tier_code': tier.code,
            'channel': 'revenuecat',
            'status': 'cancelled',
          });
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _purchasingApple = false);
        AppToast.show(
          context,
          message: l10n.membershipPurchaseFailed('$e'),
        );
        Analytics.track(AnalyticsEvents.membershipPurchaseOutcome, {
          'tier_code': tier.code,
          'channel': 'revenuecat',
          'status': 'failed',
        });
      }
      return;
    }
    if (useApple) {
      try {
        setState(() => _purchasingApple = true);
        final ok = await RevenueCatService.instance.purchaseTier(tier.code);
        if (!mounted) return;
        setState(() => _purchasingApple = false);
        if (ok) {
          await _onRcPurchaseSuccess(tier.code);
          Analytics.track(AnalyticsEvents.membershipPurchaseOutcome, {
            'tier_code': tier.code,
            'channel': 'revenuecat',
            'status': 'success',
          });
        } else {
          Analytics.track(AnalyticsEvents.membershipPurchaseOutcome, {
            'tier_code': tier.code,
            'channel': 'revenuecat',
            'status': 'cancelled',
          });
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _purchasingApple = false);
        AppToast.show(
          context,
          message: l10n.membershipPurchaseFailed('$e'),
        );
        Analytics.track(AnalyticsEvents.membershipPurchaseOutcome, {
          'tier_code': tier.code,
          'channel': 'revenuecat',
          'status': 'failed',
        });
      }
      return;
    }
    if (overseasCtx) {
      AppToast.show(
        context,
        message: tier.productType == 'SUBSCRIPTION'
            ? l10n.membershipRcUnavailable
            : l10n.membershipOverseasNoAlipay,
      );
      return;
    }
    if (Env.prodServiceRegion == ServiceRegion.international) {
      AppToast.show(context, message: l10n.membershipOverseasNoAlipay);
      return;
    }
    try {
      final resp = await createMembershipOrder(targetTier: tier.code, channel: 'ALIPAY');
      setState(() => _pendingOrderNo = resp.order.orderNo);
      _startPolling(resp.order.orderNo);
      final orderStr = resp.alipayOrderString;
      if (orderStr != null && orderStr.isNotEmpty) {
        final result = await Tobias().pay(orderStr);
        if (!mounted) return;
        final raw = result['resultStatus'] ?? result['result_status'];
        final status = raw is int ? raw.toString() : (raw?.toString() ?? '');
        switch (status) {
          case '9000':
            break;
          case '6001':
            AppToast.show(context, message: l10n.membershipPaymentCancelled);
            break;
          case '8000':
          case '6004':
            AppToast.show(context, message: l10n.membershipPaymentPending);
            break;
          case '6002':
            AppToast.show(context, message: l10n.membershipNetworkError);
            break;
          case '4000':
            AppToast.show(context, message: l10n.membershipOrderPayFailed);
            break;
          default:
            AppToast.show(
              context,
              message: l10n.membershipCompletePaymentInApp,
            );
        }
        Analytics.track(AnalyticsEvents.membershipPurchaseOutcome, {
          'tier_code': tier.code,
          'channel': 'alipay_app',
          'pay_status': status,
        });
      } else if (Platform.isAndroid || Platform.isIOS) {
        if (!mounted) return;
        AppToast.show(
          context,
          message: l10n.membershipAlipayAppNotConfigured,
        );
      } else if (resp.alipayPayUrl != null && resp.alipayPayUrl!.isNotEmpty) {
        await launchUrl(Uri.parse(resp.alipayPayUrl!), mode: LaunchMode.externalApplication);
        if (!mounted) return;
        AppToast.show(context, message: l10n.membershipOrderCreatedAlipay);
      } else {
        if (!mounted) return;
        AppToast.show(context, message: l10n.membershipOrderCreatedAlipay);
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, message: l10n.membershipPurchaseFailed('$e'));
      Analytics.track(AnalyticsEvents.membershipPurchaseOutcome, {
        'tier_code': tier.code,
        'channel': 'alipay_app',
        'status': 'failed',
      });
    }
  }

  void _startPolling(String orderNo) {
    _pollTimer?.cancel();
    _pollStartedAt = DateTime.now();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        // 5min hard cap so the timer doesn't run forever when the user closes
        // the desktop browser without paying.
        if (_pollStartedAt != null &&
            DateTime.now().difference(_pollStartedAt!) >
                const Duration(minutes: 5)) {
          _pollTimer?.cancel();
          if (mounted) setState(() => _pendingOrderNo = null);
          return;
        }
        final order = await getMembershipOrder(orderNo);
        if (order.status == 'GRANTED') {
          _pollTimer?.cancel();
          await _load();
          if (!mounted) return;
          setState(() => _pendingOrderNo = null);
          AppToast.show(context, message: AppLocalizations.of(context).membershipPurchaseSuccessActive);
        }
      } catch (_) {}
    });
  }

  /// After RC purchase/restore, poll until webhook grants [expectedTier] or 5min elapse.
  void _startMePollingForUpgrade(String expectedTier) {
    _pollTimer?.cancel();
    _pollStartedAt = DateTime.now();
    final normalizedExpected = expectedTier.split('_').first.toUpperCase();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      try {
        if (_pollStartedAt != null &&
            DateTime.now().difference(_pollStartedAt!) >
                const Duration(minutes: 5)) {
          _pollTimer?.cancel();
          if (mounted) {
            setState(() {
              _openingStripe = false;
              _pendingOrderNo = null;
            });
          }
          return;
        }
        final me = await fetchMyMembership();
        final reached =
            me.tierCode.toUpperCase() == normalizedExpected;
        if (reached) {
          _pollTimer?.cancel();
          if (!mounted) return;
          setState(() {
            _me = me;
            _openingStripe = false;
            _pendingOrderNo = null;
          });
          AppToast.show(
            context,
            message: AppLocalizations.of(context).membershipPurchaseSuccessActive,
          );
        }
      } catch (_) {}
    });
  }

  Future<void> _onRcPurchaseSuccess(String tierCode) async {
    await _load();
    if (!mounted) return;
    _startMePollingForUpgrade(tierCode);
    AppToast.show(
      context,
      message: AppLocalizations.of(context).membershipPurchaseSuccessSync,
    );
  }

  Future<void> _restoreRcPurchases() async {
    final l10n = AppLocalizations.of(context);
    if (!RevenueCatService.instance.canRestorePurchases) {
      AppToast.show(context, message: l10n.membershipRcUnavailable);
      return;
    }
    try {
      setState(() => _restoringPurchases = true);
      final ok = await RevenueCatService.instance.restorePurchases();
      if (!mounted) return;
      setState(() => _restoringPurchases = false);
      if (!ok) return;
      await _load();
      if (!mounted) return;
      final tierCode = _me?.tierCode ?? 'FREE';
      if (tierCode.toUpperCase() != 'FREE') {
        _startMePollingForUpgrade(tierCode);
      }
      AppToast.show(context, message: l10n.membershipRestoreSuccess);
      Analytics.track(AnalyticsEvents.membershipPurchaseOutcome, {
        'tier_code': tierCode,
        'channel': 'revenuecat',
        'status': 'restore_success',
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _restoringPurchases = false);
      AppToast.show(context, message: l10n.membershipRestoreFailed('$e'));
      Analytics.track(AnalyticsEvents.membershipPurchaseOutcome, {
        'channel': 'revenuecat',
        'status': 'restore_failed',
      });
    }
  }

  PurchaseSurface _resolvePurchaseSurface(MembershipTier tier) {
    final overseas = isOverseasAppContext(_tiers);
    if (RuntimePlatform.isDesktop) {
      return overseas ? PurchaseSurface.stripeWeb : PurchaseSurface.alipayPcWeb;
    }
    if (overseas && tier.productType == 'SUBSCRIPTION') {
      return PurchaseSurface.native;
    }
    if (!overseas) {
      if (Platform.isIOS && RevenueCatService.instance.canUseApplePurchase) {
        return PurchaseSurface.native;
      }
      return PurchaseSurface.alipayApp;
    }
    return PurchaseSurface.native;
  }

  bool _isOverseasUpgrade(MembershipTier tier) {
    final currentRank = overseasTierRankFromTierCode(_me?.tierCode ?? 'FREE');
    final targetBase = tier.code.split('_').first.toUpperCase();
    final targetRank = overseasTierRankFromTierCode(targetBase);
    return currentRank > 0 && targetRank > currentRank;
  }

  Future<void> _handleChannelLocked(MembershipChannelDecision decision) async {
    final l10n = AppLocalizations.of(context);
    switch (decision.reason) {
      case LockReason.boundToStripeManageOnWeb:
        AppToast.show(context, message: l10n.membershipChannelLockedStripe);
        await _openStripePortal();
        break;
      case LockReason.boundToAppStore:
        AppToast.show(context, message: l10n.membershipChannelLockedAppStore);
        try {
          await launchUrl(
            Uri.parse('https://apps.apple.com/account/subscriptions'),
            mode: LaunchMode.externalApplication,
          );
        } catch (_) {}
        break;
      case LockReason.boundToPlayStore:
        if (Platform.isIOS) {
          AppToast.show(
            context,
            message: l10n.membershipChannelLockedOtherPlatform,
          );
        } else {
          AppToast.show(context, message: l10n.membershipChannelLockedPlayStore);
          try {
            await launchUrl(
              Uri.parse('https://play.google.com/store/account/subscriptions'),
              mode: LaunchMode.externalApplication,
            );
          } catch (_) {}
        }
        break;
      case LockReason.lifetimeMainland:
        AppToast.show(context, message: l10n.membershipChannelLifetime);
        break;
      case LockReason.none:
        break;
    }
  }

  Future<void> _openStripePortal() async {
    try {
      final url = await createStripeBillingPortalSession();
      if (url.isEmpty) return;
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        message: AppLocalizations.of(context).membershipManageStripeFailed,
      );
    }
  }

  Future<void> _buyOverseasStripe(MembershipTier tier, {required bool isUpgrade}) async {
    final l10n = AppLocalizations.of(context);
    final priceId = Env.stripePriceIdForTierCode(tier.code);
    if (priceId.isEmpty) {
      AppToast.show(context, message: l10n.membershipStripePriceMissing);
      return;
    }
    try {
      setState(() => _openingStripe = true);
      if (isUpgrade && (_me?.stripeSubscriptionPresent ?? false)) {
        // Same Stripe subscription, just upgrade the line item — no browser hop needed.
        await updateStripeSubscriptionPrice(priceId);
        await _load();
        if (!mounted) return;
        setState(() => _openingStripe = false);
        AppToast.show(context, message: l10n.membershipUpgradeStripeSuccess);
        Analytics.track(AnalyticsEvents.membershipPurchaseOutcome, {
          'tier_code': tier.code,
          'channel': 'stripe',
          'status': 'success',
        });
        return;
      }
      final url = await createStripeCheckoutSession(
        priceId: priceId,
        platform: RuntimePlatform.platformTag,
      );
      if (url.isEmpty) {
        if (!mounted) return;
        setState(() => _openingStripe = false);
        AppToast.show(context, message: l10n.membershipStripeCheckoutFailed);
        Analytics.track(AnalyticsEvents.membershipPurchaseOutcome, {
          'tier_code': tier.code,
          'channel': 'stripe',
          'status': 'failed',
        });
        return;
      }
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!mounted) return;
      AppToast.show(context, message: l10n.membershipOpenBrowserToPay);
      _startMePollingForUpgrade(tier.code);
      Analytics.track(AnalyticsEvents.membershipPurchaseOutcome, {
        'tier_code': tier.code,
        'channel': 'stripe',
        'status': 'browser_opened',
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _openingStripe = false);
      AppToast.show(context, message: l10n.membershipPurchaseFailed('$e'));
      Analytics.track(AnalyticsEvents.membershipPurchaseOutcome, {
        'tier_code': tier.code,
        'channel': 'stripe',
        'status': 'failed',
      });
    }
  }

  Future<void> _buyMainlandAlipayDesktop(MembershipTier tier) async {
    final l10n = AppLocalizations.of(context);
    try {
      final resp =
          await createMembershipOrder(targetTier: tier.code, channel: 'ALIPAY');
      setState(() => _pendingOrderNo = resp.order.orderNo);
      _startPolling(resp.order.orderNo);
      // Prefer the PC PagePay URL on desktop; fall back to the WAP URL for legacy backends.
      final url = (resp.alipayPcPayUrl != null && resp.alipayPcPayUrl!.isNotEmpty)
          ? resp.alipayPcPayUrl!
          : (resp.alipayPayUrl ?? '');
      if (url.isEmpty) {
        if (!mounted) return;
        AppToast.show(context, message: l10n.membershipAlipayAppNotConfigured);
        return;
      }
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!mounted) return;
      AppToast.show(context, message: l10n.membershipOpenBrowserToPay);
      Analytics.track(AnalyticsEvents.membershipPurchaseOutcome, {
        'tier_code': tier.code,
        'channel': 'alipay_pc_web',
        'status': 'browser_opened',
      });
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, message: l10n.membershipPurchaseFailed('$e'));
      Analytics.track(AnalyticsEvents.membershipPurchaseOutcome, {
        'tier_code': tier.code,
        'channel': 'alipay_pc_web',
        'status': 'failed',
      });
    }
  }

  List<Widget> _buildOverseasSubscriptionPaywall(
    BuildContext context,
    ThemeData theme,
    AppThemeColors colors,
    AppLocalizations l10n,
  ) {
    final maxPct = maxYearlySavingsPercentAcrossPlans(_tiers);
    final overseasSubscription = Env.prodServiceRegion == ServiceRegion.international &&
        _tiers.any((t) => t.productType == 'SUBSCRIPTION');
    final useStoreRc =
        overseasSubscription && RevenueCatService.instance.canUseOverseasStorePurchase;
    final useApple = Platform.isIOS &&
        RevenueCatService.instance.canUseApplePurchase &&
        !useStoreRc;

    return [
      const SizedBox(height: AppSpacing.sm),
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<OverseasBilling>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment<OverseasBilling>(
                    value: OverseasBilling.monthly,
                    label: Text(l10n.membershipBillingMonthly),
                  ),
                  ButtonSegment<OverseasBilling>(
                    value: OverseasBilling.yearly,
                    label: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: Text(l10n.membershipBillingYearly)),
                        if (maxPct != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.15),
                              borderRadius: AppRadius.small,
                            ),
                            child: Text(
                              '−$maxPct%',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                selected: {_overseasBilling},
                onSelectionChanged: (s) {
                  if (s.isEmpty) return;
                  setState(() => _overseasBilling = s.first);
                },
              ),
              SizedBox(
                height: 44,
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: _overseasBilling == OverseasBilling.yearly && maxPct != null
                      ? Text(
                          l10n.membershipSavingsVsMonthlyYear(maxPct),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              Text(
                Platform.isIOS
                    ? l10n.membershipOverseasSubscribeHintIos
                    : l10n.membershipOverseasSubscribeHint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: colors.textTertiary),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      ...kOverseasPlanOrder.map((planId) {
        final tier = tierForPlanAndBilling(_tiers, planId, _overseasBilling);
        final monthly = tierForPlanAndBilling(_tiers, planId, OverseasBilling.monthly);
        final yearly = tierForPlanAndBilling(_tiers, planId, OverseasBilling.yearly);
        final planSavings = monthly != null && yearly != null
            ? yearlySavingsPercent(monthly.priceCent, yearly.priceCent)
            : 0;
        final uploadGib = kOverseasPlanUploadGib[planId] ?? 0;
        final isPro = planId == 'PRO';

        if (tier == null) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: Text(
                    '—',
                    style: theme.textTheme.bodyMedium?.copyWith(color: colors.textTertiary),
                  ),
                ),
              ),
            ),
          );
        }

        final disabled = overseasSubscriptionPurchaseDisabled(
          me: _me,
          tier: tier,
          pendingOrder: _pendingOrderNo != null,
          purchasing: _purchasingApple || _openingStripe || _restoringPurchases,
        );
        final rcConfigured = RevenueCatService.instance.canUseOverseasStorePurchase;
        // On desktop we replace RC with Stripe-via-browser; don't require RC config.
        final purchaseBlocked =
            disabled || (useStoreRc && !rcConfigured && !RuntimePlatform.isDesktop);

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.medium,
              side: isPro
                  ? BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.45), width: 2)
                  : BorderSide(color: colors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: AppSpacing.xs,
                              runSpacing: 6,
                              children: [
                                Text(tier.name, style: theme.textTheme.titleMedium),
                                if (isPro)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      l10n.membershipPlanPopular,
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.onPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (_overseasBilling == OverseasBilling.yearly && planSavings > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceMuted,
                                    borderRadius: AppRadius.small,
                                  ),
                                  child: Text(
                                    l10n.membershipPlanYearlySave(planSavings),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceMuted,
                          borderRadius: AppRadius.small,
                        ),
                        child: Text(
                          l10n.membershipDeviceBadgeDevices(tier.deviceLimit),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _overseasBilling == OverseasBilling.yearly
                        ? l10n.membershipPricePerYear(formatUsdPrice(tier.priceCent))
                        : l10n.membershipPricePerMonth(formatUsdPrice(tier.priceCent)),
                    style: theme.textTheme.headlineSmall,
                  ),
                  if (_overseasBilling == OverseasBilling.yearly) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.membershipPricePerMonthEquiv(
                        formatUsdPrice((tier.priceCent / 12).round()),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.membershipTierSubtitleSubscription,
                    style: theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _bulletLine(
                    theme,
                    colors,
                    l10n.membershipFeatureDevices(tier.deviceLimit),
                  ),
                  _bulletLine(
                    theme,
                    colors,
                    l10n.membershipFeatureUploadHosted(uploadGib),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (disabled && !(_pendingOrderNo != null || _purchasingApple))
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(
                        l10n.membershipCannotBuyLowerTier,
                        style: theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                      ),
                    ),
                  FilledButton(
                    onPressed: purchaseBlocked ? null : () => _buy(tier),
                    child: Text(_overseasPaywallButtonLabel(
                      l10n: l10n,
                      tier: tier,
                      useStoreRc: useStoreRc,
                      useApple: useApple,
                    )),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
      if (useStoreRc || useApple) ..._buildRestorePurchasesButton(context, theme, colors, l10n),
    ];
  }

  List<Widget> _buildRestorePurchasesButton(
    BuildContext context,
    ThemeData theme,
    AppThemeColors colors,
    AppLocalizations l10n,
  ) {
    if (!RevenueCatService.instance.canRestorePurchases) {
      return const [];
    }
    return [
      const SizedBox(height: AppSpacing.sm),
      Center(
        child: TextButton(
          onPressed: (_purchasingApple || _restoringPurchases || _openingStripe)
              ? null
              : _restoreRcPurchases,
          child: _restoringPurchases
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                )
              : Text(l10n.membershipRestorePurchases),
        ),
      ),
    ];
  }

  String _overseasPaywallButtonLabel({
    required AppLocalizations l10n,
    required MembershipTier tier,
    required bool useStoreRc,
    required bool useApple,
  }) {
    if (_purchasingApple) return l10n.membershipPurchasing;
    if (_openingStripe) return l10n.membershipOpeningStripe;
    if (_pendingOrderNo != null) return l10n.membershipWaitingPayment;
    if (RuntimePlatform.isDesktop) {
      return _isOverseasUpgrade(tier)
          ? l10n.membershipUpgradeStripe
          : l10n.membershipSubscribeStripe;
    }
    if (useStoreRc) return l10n.membershipSubscribeInApp;
    if (useApple) return l10n.membershipBuyApple;
    return l10n.membershipSubscribeInApp;
  }

  /// Channel-affinity informational banner shown above the tier list.
  /// Shows different content for Stripe / App Store / Play Store / Alipay-lifetime users.
  List<Widget> _buildChannelLockBanner(
    BuildContext context,
    ThemeData theme,
    AppThemeColors colors,
    AppLocalizations l10n,
  ) {
    final channel = (_me?.paymentChannel ?? 'FREE').toUpperCase();
    if (channel == 'FREE') return const [];

    // Skip the banner entirely on the channel that natively owns the subscription
    // (e.g. show nothing on iOS APPLE_RC — that's the home channel, no warning needed).
    if (channel == PaymentChannel.appleRc && RuntimePlatform.isIos) return const [];
    if (channel == PaymentChannel.googleRc && RuntimePlatform.isAndroid) return const [];
    if (channel == PaymentChannel.alipayLifetime && !isOverseasAppContext(_tiers)) {
      // Mainland lifetime user on mainland UI: no warning, this is the home surface.
      return const [];
    }

    String message;
    String? actionLabel;
    VoidCallback? action;
    switch (channel) {
      case PaymentChannel.stripe:
        message = l10n.membershipChannelLockedStripe;
        actionLabel = l10n.membershipManageStripe;
        action = _openingStripe ? null : () => _openStripePortal();
        break;
      case PaymentChannel.appleRc:
        message = l10n.membershipChannelLockedAppStore;
        actionLabel = l10n.membershipOpenAppStoreSubs;
        action = () => launchUrl(
              Uri.parse('https://apps.apple.com/account/subscriptions'),
              mode: LaunchMode.externalApplication,
            );
        break;
      case PaymentChannel.googleRc:
        if (Platform.isIOS) {
          message = l10n.membershipChannelLockedOtherPlatform;
        } else {
          message = l10n.membershipChannelLockedPlayStore;
          actionLabel = l10n.membershipOpenPlayStoreSubs;
          action = () => launchUrl(
                Uri.parse('https://play.google.com/store/account/subscriptions'),
                mode: LaunchMode.externalApplication,
              );
        }
        break;
      case PaymentChannel.alipayLifetime:
        message = l10n.membershipChannelLifetime;
        break;
      default:
        return const [];
    }

    return [
      const SizedBox(height: AppSpacing.sm),
      Card(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.medium,
          side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message, style: theme.textTheme.bodyMedium),
                    if (action != null && actionLabel != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          onPressed: action,
                          child: Text(actionLabel),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _bulletLine(
    ThemeData theme,
    AppThemeColors colors,
    String text,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);
    final tierCode = _me?.tierCode ?? 'FREE';

    final overseasApp = isOverseasAppContext(_tiers);
    final showOverseasPaywall = showOverseasSubscriptionPaywall(_tiers);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.membershipCenterTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppSize.contentMaxWidth),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.membershipCurrentTier, style: theme.textTheme.titleMedium),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              l10n.membershipTierSummary(
                                _me?.tierName ?? 'Free',
                                _me?.deviceLimit ?? 0,
                              ),
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.membershipBoundDevices(_me?.currentDeviceCount ?? 0),
                              style: theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                            ),
                            if ((_me?.addonPacks ?? 0) > 0)
                              Text(
                                l10n.membershipAddonLine(
                                  _me!.addonPacks,
                                  _me!.addonPacks * 5,
                                ),
                                style: theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                              ),
                            if ((_me?.tierCode ?? 'FREE').toUpperCase() != 'FREE' &&
                                _me?.subscriptionExpiresAtMs != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                _subscriptionScheduleLine(context, _me!),
                                style: theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    ..._buildChannelLockBanner(context, theme, colors, l10n),
                    if (!overseasApp && (_me?.tierCode ?? 'FREE').toUpperCase() == 'FREE') ...[
                      const SizedBox(height: AppSpacing.sm),
                      Card(
                        child: InkWell(
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const MembershipMigrationScreen(),
                              ),
                            );
                            if (result == true) {
                              await _load();
                            }
                          },
                          borderRadius: AppRadius.medium,
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.swap_horiz,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.membershipMigrationCardTitle,
                                        style: theme.textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        l10n.membershipMigrationCardSubtitle,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: colors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (showOverseasPaywall) ...[
                      ..._buildOverseasSubscriptionPaywall(context, theme, colors, l10n),
                    ] else ...[
                      const SizedBox(height: AppSpacing.md),
                      ..._tiers
                          .where((tier) =>
                              overseasApp ||
                              shouldShowMainlandTier(tier, tierCode))
                          .map((tier) {
                        final overseasSubscription = Env.prodServiceRegion ==
                                ServiceRegion.international &&
                            tier.productType == 'SUBSCRIPTION';
                        final useStoreRc = overseasSubscription &&
                            RevenueCatService.instance.canUseOverseasStorePurchase;
                        final useApple = Platform.isIOS &&
                            RevenueCatService.instance.canUseApplePurchase &&
                            !useStoreRc;
                        final isAddon = tier.isAddon;
                        final canBuyAddon = _me?.canBuyAddon ?? false;
                        final isUsdSub =
                            tier.currency == 'USD' && tier.productType == 'SUBSCRIPTION';
                        final disabled = isAddon
                            ? isMainlandTierPurchaseDisabled(
                                tier,
                                _me,
                                pendingOrder: _pendingOrderNo != null,
                                purchasing: _purchasingApple ||
                                    _openingStripe ||
                                    _restoringPurchases,
                              )
                            : (isUsdSub
                                  ? overseasSubscriptionPurchaseDisabled(
                                      me: _me,
                                      tier: tier,
                                      pendingOrder: _pendingOrderNo != null,
                                      purchasing: _purchasingApple ||
                                          _openingStripe ||
                                          _restoringPurchases,
                                    )
                                  : isMainlandTierPurchaseDisabled(
                                      tier,
                                      _me,
                                      pendingOrder: _pendingOrderNo != null,
                                      purchasing: _purchasingApple ||
                                          _openingStripe ||
                                          _restoringPurchases,
                                    ));
                        final displayPriceCent = isUsdSub
                            ? tier.priceCent
                            : mainlandTierDisplayPriceCent(tier);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(tier.name, style: theme.textTheme.titleMedium),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.xs,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.surfaceMuted,
                                          borderRadius: AppRadius.small,
                                        ),
                                        child: Text(
                                          isAddon
                                              ? l10n.membershipDeviceBadgeAddon(
                                                  tier.deviceLimit,
                                                )
                                              : l10n.membershipDeviceBadgeDevices(
                                                  tier.deviceLimit,
                                                ),
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    tier.currency == 'USD'
                                        ? formatUsdPrice(tier.priceCent)
                                        : '¥${(displayPriceCent / 100).toStringAsFixed(0)}',
                                    style: theme.textTheme.headlineSmall,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isAddon
                                        ? l10n.membershipTierSubtitleAddon
                                        : (isUsdSub
                                            ? l10n.membershipTierSubtitleSubscription
                                            : l10n.membershipTierSubtitleBuyout),
                                    style: theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  if (isAddon && !canBuyAddon) ...[
                                    Text(
                                      l10n.membershipNeedMiniProFirst,
                                      style: theme.textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                  ],
                                  const SizedBox(height: AppSpacing.sm),
                                  FilledButton(
                                    onPressed: disabled ? null : () => _buy(tier),
                                    child: Text(
                                      _purchasingApple
                                          ? l10n.membershipPurchasing
                                          : _pendingOrderNo != null
                                              ? l10n.membershipWaitingPayment
                                              : isAddon && !canBuyAddon
                                                  ? l10n.membershipPleaseSubscribeFirst
                                                  : useStoreRc
                                                      ? l10n.membershipSubscribeInApp
                                                      : useApple
                                                          ? l10n.membershipBuyApple
                                                          : l10n.membershipBuyAlipay,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      if (Platform.isIOS &&
                          RevenueCatService.instance.canUseApplePurchase)
                        ..._buildRestorePurchasesButton(context, theme, colors, l10n),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
