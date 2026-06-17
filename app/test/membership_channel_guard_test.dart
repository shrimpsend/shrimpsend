import 'package:flutter_test/flutter_test.dart';

import 'package:app/api/membership.dart';
import 'package:app/services/membership_channel_guard.dart';

MembershipMe _me({String channel = 'FREE', bool canSwitch = true}) {
  return MembershipMe(
    tierCode: channel == 'FREE' ? 'FREE' : 'PLUS',
    tierName: 'Test',
    deviceLimit: 10,
    currentDeviceCount: 0,
    canAddDevice: true,
    paymentChannel: channel,
    canSwitchChannel: canSwitch,
  );
}

void main() {
  group('decideMembershipPurchase', () {
    test('FREE allows any surface', () {
      for (final s in PurchaseSurface.values) {
        final d = decideMembershipPurchase(me: _me(), surface: s);
        expect(d.canPurchase, isTrue, reason: 'surface=$s');
        expect(d.reason, LockReason.none);
      }
    });

    test('STRIPE-bound user can only buy via stripeWeb', () {
      final me = _me(channel: PaymentChannel.stripe, canSwitch: false);
      expect(decideMembershipPurchase(me: me, surface: PurchaseSurface.stripeWeb).canPurchase, isTrue);
      final native = decideMembershipPurchase(me: me, surface: PurchaseSurface.native);
      expect(native.canPurchase, isFalse);
      expect(native.reason, LockReason.boundToStripeManageOnWeb);
      expect(native.preferredSurface, PurchaseSurface.stripeWeb);
    });

    test('APPLE_RC-bound user routed to App Store', () {
      final me = _me(channel: PaymentChannel.appleRc, canSwitch: false);
      expect(decideMembershipPurchase(me: me, surface: PurchaseSurface.native).canPurchase, isTrue);
      final web = decideMembershipPurchase(me: me, surface: PurchaseSurface.stripeWeb);
      expect(web.canPurchase, isFalse);
      expect(web.reason, LockReason.boundToAppStore);
      expect(web.preferredSurface, PurchaseSurface.native);
    });

    test('APPLE_RC mainland upgrade must use native not alipayApp surface', () {
      final me = _me(channel: PaymentChannel.appleRc, canSwitch: false);
      final upgrade = decideMembershipPurchase(me: me, surface: PurchaseSurface.native);
      expect(upgrade.canPurchase, isTrue);
      expect(upgrade.reason, LockReason.none);

      final wrongSurface = decideMembershipPurchase(me: me, surface: PurchaseSurface.alipayApp);
      expect(wrongSurface.canPurchase, isFalse);
      expect(wrongSurface.reason, LockReason.boundToAppStore);
    });

    test('GOOGLE_RC-bound user routed to Play Store', () {
      final me = _me(channel: PaymentChannel.googleRc, canSwitch: false);
      expect(decideMembershipPurchase(me: me, surface: PurchaseSurface.native).canPurchase, isTrue);
      final web = decideMembershipPurchase(me: me, surface: PurchaseSurface.stripeWeb);
      expect(web.canPurchase, isFalse);
      expect(web.reason, LockReason.boundToPlayStore);
    });

    test('ALIPAY_LIFETIME blocks overseas Stripe upgrades', () {
      final me = _me(channel: PaymentChannel.alipayLifetime, canSwitch: false);
      final d = decideMembershipPurchase(me: me, surface: PurchaseSurface.stripeWeb);
      expect(d.canPurchase, isFalse);
      expect(d.reason, LockReason.lifetimeMainland);
    });

    test('ALIPAY_LIFETIME can still buy add-on packs on any surface', () {
      final me = _me(channel: PaymentChannel.alipayLifetime, canSwitch: false);
      for (final s in PurchaseSurface.values) {
        final d = decideMembershipPurchase(me: me, surface: s, isAddon: true);
        expect(d.canPurchase, isTrue, reason: 'surface=$s');
        expect(d.reason, LockReason.none, reason: 'surface=$s');
      }

      // Sanity: a non-addon purchase on the same user is still blocked.
      final upgrade =
          decideMembershipPurchase(me: me, surface: PurchaseSurface.stripeWeb);
      expect(upgrade.canPurchase, isFalse);
      expect(upgrade.reason, LockReason.lifetimeMainland);
    });

    test('null me allows any surface (treated as FREE)', () {
      for (final s in PurchaseSurface.values) {
        expect(decideMembershipPurchase(me: null, surface: s).canPurchase, isTrue);
      }
    });
  });

  group('overseasTierRankFromTierCode', () {
    test('ranks tiers', () {
      expect(overseasTierRankFromTierCode('FREE'), 0);
      expect(overseasTierRankFromTierCode('PLUS'), 1);
      expect(overseasTierRankFromTierCode('PRO'), 2);
      expect(overseasTierRankFromTierCode('ULTRA'), 3);
      expect(overseasTierRankFromTierCode('plus'), 1);
      expect(overseasTierRankFromTierCode('???'), 0);
    });
  });
}
