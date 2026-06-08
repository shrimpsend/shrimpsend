import 'package:flutter/widgets.dart';

import '../config/env.dart';
import '../preferences/service_region.dart';
import 'generated/app_localizations.dart';

/// Desktop window title and tray tooltip from build flavor.
String desktopWindowTitle() =>
    Env.overseasBuild ? 'ShrimpSend' : '虾传';

/// UI brand line (虾传 vs ShrimpSend) from region, localized.
String brandProductName(AppLocalizations l10n, ServiceRegion region) {
  return region == ServiceRegion.mainlandChina
      ? l10n.brandNameMainlandChina
      : l10n.brandNameInternational;
}

/// Same as [brandProductName] using the ambient locale from [context].
String brandDisplayName(BuildContext context, ServiceRegion region) {
  return brandProductName(AppLocalizations.of(context), region);
}
