import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../logger.dart';
import '../config/feedmatter_env.dart';
import '../config/openpanel_env.dart';
import '../services/feedmatter_bootstrap.dart';
import '../services/openpanel_bootstrap.dart';
import 'env.dart';

const String _divider =
    '============================================================';

const int _keyColumnWidth = 20;

bool _scheduled = false;

/// Schedule the boot env snapshot to run after the first frame.
///
/// On cold start in debug builds the IDE console attaches *after* `main()`
/// begins, so logs emitted before the first paint can be dropped from the
/// IDE output (they are still written to [AppLogFile] though). Deferring
/// until after the first frame ensures the snapshot is visible in the
/// console on cold start as well as on hot reload/restart.
///
/// Idempotent: subsequent calls within the same isolate are no-ops.
void scheduleBootEnvSnapshot() {
  if (_scheduled) return;
  _scheduled = true;
  SchedulerBinding.instance.addPostFrameCallback((_) {
    unawaited(_logBootEnvSnapshot());
  });
}

/// Print build/runtime environment parameters to [logBoot] once.
///
/// Output is wrapped between divider lines so the snapshot is easy to spot
/// in IDE console. Should be called after [LocaleRegionStore] resolves the
/// service region so [Env.apiUrl] and [Env.centrifugoWs] reflect their
/// final values; [scheduleBootEnvSnapshot] guarantees this ordering when
/// invoked at the end of `main()`.
Future<void> _logBootEnvSnapshot() async {
  final pkg = await _safeReadPackageInfo();

  logBoot.info(_divider);
  logBoot.info('[Boot] Env snapshot / 启动环境参数');
  logBoot.info(_divider);
  for (final entry in _buildEntries(pkg)) {
    logBoot.info('${entry.key.padRight(_keyColumnWidth)}: ${entry.value}');
  }
  logBoot.info(_divider);
}

Future<PackageInfo?> _safeReadPackageInfo() async {
  try {
    return await PackageInfo.fromPlatform();
  } catch (_) {
    return null;
  }
}

List<MapEntry<String, String>> _buildEntries(PackageInfo? pkg) => [
      MapEntry(
        'platform',
        '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      ),
      MapEntry('kDebugMode', '$kDebugMode'),
      MapEntry('kProfileMode', '$kProfileMode'),
      MapEntry('kReleaseMode', '$kReleaseMode'),
      MapEntry(
        'appVersion',
        '${pkg?.version ?? '-'} (build ${pkg?.buildNumber ?? '-'})',
      ),
      MapEntry('packageName', pkg?.packageName ?? '-'),
      MapEntry('AppEnv.current', '${Env.current.name} (${Env.label})'),
      MapEntry('OVERSEAS_BUILD', '${Env.overseasBuild}'),
      MapEntry('ANDROID_PLAY_DIST', '${Env.androidPlayDistribution}'),
      MapEntry('serviceRegion', Env.prodServiceRegion.name),
      MapEntry('apiUrl', Env.apiUrl),
      MapEntry('centrifugoWs', Env.centrifugoWs),
      MapEntry('openpanel', OpenpanelBootstrap.snapshotSummary()),
      MapEntry('feedmatter', FeedmatterBootstrap.snapshotSummary()),
      MapEntry(
        'feedmatter.cnSecret',
        FeedmatterEnv.cnApiSecret.isEmpty ? '(empty)' : '(set)',
      ),
      MapEntry(
        'feedmatter.intlSecret',
        FeedmatterEnv.intlApiSecret.isEmpty ? '(empty)' : '(set)',
      ),
      MapEntry(
        'openpanel.cnSecret',
        OpenpanelEnv.cnAppClientSecret.isEmpty ? '(empty)' : '(set)',
      ),
      MapEntry(
        'openpanel.intlSecret',
        OpenpanelEnv.intlAppClientSecret.isEmpty ? '(empty)' : '(set)',
      ),
      MapEntry('rc.storeMode', Env.rcStoreMode),
      MapEntry('rc.flavor', Env.overseasBuild ? 'intl' : 'cn'),
      MapEntry('rc.appleApiKey', _mask(Env.rcAppleApiKey)),
      MapEntry('rc.product.mini', Env.rcProductMini),
      MapEntry('rc.product.pro', Env.rcProductPro),
      MapEntry('rc.product.addon5', Env.rcProductAddon5),
      MapEntry('rc.plus.monthly', Env.rcPlusMonthly),
      MapEntry('rc.plus.yearly', Env.rcPlusYearly),
      MapEntry('rc.pro.monthly', Env.rcProMonthly),
      MapEntry('rc.pro.yearly', Env.rcProYearly),
      MapEntry('rc.ultra.monthly', Env.rcUltraMonthly),
      MapEntry('rc.ultra.yearly', Env.rcUltraYearly),
      MapEntry('stripe.plus.monthly', _orEmpty(Env.stripePricePlusMonthly)),
      MapEntry('stripe.plus.yearly', _orEmpty(Env.stripePricePlusYearly)),
      MapEntry('stripe.pro.monthly', _orEmpty(Env.stripePriceProMonthly)),
      MapEntry('stripe.pro.yearly', _orEmpty(Env.stripePriceProYearly)),
      MapEntry('stripe.ultra.monthly', _orEmpty(Env.stripePriceUltraMonthly)),
      MapEntry('stripe.ultra.yearly', _orEmpty(Env.stripePriceUltraYearly)),
    ];

String _mask(String v) {
  if (v.isEmpty) return '(empty)';
  if (v.length <= 6) return '***';
  return '${v.substring(0, 3)}***${v.substring(v.length - 3)}';
}

String _orEmpty(String v) => v.isEmpty ? '(empty)' : v;
