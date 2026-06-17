import '../api/membership.dart';

/// Active payment channel values returned by the backend.
class PaymentChannel {
  PaymentChannel._();

  static const free = 'FREE';
  static const appleRc = 'APPLE_RC';
  static const googleRc = 'GOOGLE_RC';
  static const stripe = 'STRIPE';
  static const alipayLifetime = 'ALIPAY_LIFETIME';
}

/// Which UI surface should host this client's purchase/upgrade buttons.
enum PurchaseSurface { native, stripeWeb, alipayApp, alipayPcWeb, none }

/// Reason for disabling/redirecting a purchase action.
enum LockReason {
  /// No lock — purchase / upgrade is allowed from this surface.
  none,

  /// Membership is bound to Stripe (web); ask user to upgrade on the web.
  boundToStripeManageOnWeb,

  /// Membership is bound to iOS App Store; ask user to manage on iPhone/iPad.
  boundToAppStore,

  /// Membership is bound to Google Play; ask user to manage on the device.
  boundToPlayStore,

  /// Lifetime mainland (Alipay) — no further upgrade path on overseas Stripe.
  lifetimeMainland,
}

class MembershipChannelDecision {
  final bool canPurchase;
  final LockReason reason;

  /// Suggested surface to route the user to. Only meaningful when
  /// [canPurchase] is false.
  final PurchaseSurface preferredSurface;

  const MembershipChannelDecision({
    required this.canPurchase,
    required this.reason,
    required this.preferredSurface,
  });

  const MembershipChannelDecision.allow(this.preferredSurface)
      : canPurchase = true,
        reason = LockReason.none;
}

/// Pure function: given the current membership state and the surface that
/// initiated the buy/upgrade action, decide whether the action is allowed
/// or should be redirected to another channel.
///
/// [surface] should reflect *where* the user clicked (e.g. desktop -> [PurchaseSurface.stripeWeb]
/// for overseas, [PurchaseSurface.alipayPcWeb] for mainland).
///
/// [isAddon] marks one-shot add-on (device pack) purchases. Add-ons are
/// channel-independent top-ups and must NOT be blocked by the upgrade
/// channel-affinity guard (e.g. a mainland lifetime member can still buy
/// add-on packs via Alipay).
MembershipChannelDecision decideMembershipPurchase({
  required MembershipMe? me,
  required PurchaseSurface surface,
  bool isAddon = false,
}) {
  if (isAddon) {
    return MembershipChannelDecision.allow(surface);
  }

  final channel = (me?.paymentChannel ?? PaymentChannel.free).toUpperCase();

  if (channel == PaymentChannel.free || (me?.canSwitchChannel ?? true)) {
    return MembershipChannelDecision.allow(surface);
  }

  switch (channel) {
    case PaymentChannel.stripe:
      if (surface == PurchaseSurface.stripeWeb) {
        return MembershipChannelDecision.allow(surface);
      }
      return const MembershipChannelDecision(
        canPurchase: false,
        reason: LockReason.boundToStripeManageOnWeb,
        preferredSurface: PurchaseSurface.stripeWeb,
      );
    case PaymentChannel.appleRc:
      if (surface == PurchaseSurface.native) {
        return MembershipChannelDecision.allow(surface);
      }
      return const MembershipChannelDecision(
        canPurchase: false,
        reason: LockReason.boundToAppStore,
        preferredSurface: PurchaseSurface.native,
      );
    case PaymentChannel.googleRc:
      if (surface == PurchaseSurface.native) {
        return MembershipChannelDecision.allow(surface);
      }
      return const MembershipChannelDecision(
        canPurchase: false,
        reason: LockReason.boundToPlayStore,
        preferredSurface: PurchaseSurface.native,
      );
    case PaymentChannel.alipayLifetime:
      return const MembershipChannelDecision(
        canPurchase: false,
        reason: LockReason.lifetimeMainland,
        preferredSurface: PurchaseSurface.none,
      );
    default:
      return MembershipChannelDecision.allow(surface);
  }
}

/// Convenience: rank for overseas tier codes ("FREE/PLUS/PRO/ULTRA"). Used in
/// the screen to detect upgrades (same rank or lower is not allowed).
int overseasTierRankFromTierCode(String tierCode) {
  switch (tierCode.toUpperCase()) {
    case 'ULTRA':
      return 3;
    case 'PRO':
      return 2;
    case 'PLUS':
      return 1;
    default:
      return 0;
  }
}
