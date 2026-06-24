import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/webdav.dart';
import 'webdav_shell_screen.dart';

/// Opens the WebDAV client shell (4-tab experience).
class WebDavBrowserScreen extends ConsumerWidget {
  final WebDavConnectionSummary connection;

  const WebDavBrowserScreen({super.key, required this.connection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return WebDavShellScreen(connection: connection);
  }
}
