import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/webdav.dart';
import '../../providers/auth_provider.dart';
import '../../providers/webdav_provider.dart';
import '../../screens/webdav_shell_screen.dart';

/// Keeps visited [WebDavShellScreen] instances alive for instant wide-layout switching.
class WebDavPaneHost extends ConsumerStatefulWidget {
  final WebDavConnectionSummary? connection;
  final bool embedded;
  final VoidCallback? onBack;

  const WebDavPaneHost({
    super.key,
    required this.connection,
    this.embedded = true,
    this.onBack,
  });

  @override
  ConsumerState<WebDavPaneHost> createState() => _WebDavPaneHostState();
}

class _WebDavPaneHostState extends ConsumerState<WebDavPaneHost> {
  final Map<int, WebDavConnectionSummary> _materializedShells = {};

  @override
  void initState() {
    super.initState();
    _materialize(widget.connection);
  }

  @override
  void didUpdateWidget(covariant WebDavPaneHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _materialize(widget.connection);
    _pruneStaleShells();
  }

  void _materialize(WebDavConnectionSummary? connection) {
    if (connection == null) return;
    _materializedShells[connection.id] = connection;
  }

  void _pruneStaleShells() {
    if (!ref.read(authProvider).isLoggedIn) {
      _materializedShells.clear();
      return;
    }
    final liveIds = {
      for (final conn
          in ref.read(webDavConnectionsProvider).valueOrNull ??
              const <WebDavConnectionSummary>[])
        conn.id,
    };
    _materializedShells.removeWhere((id, _) => !liveIds.contains(id));
    for (final conn
        in ref.read(webDavConnectionsProvider).valueOrNull ??
            const <WebDavConnectionSummary>[]) {
      final cached = _materializedShells[conn.id];
      if (cached != null) {
        _materializedShells[conn.id] = conn;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (prev?.isLoggedIn == true && !next.isLoggedIn) {
        setState(() => _materializedShells.clear());
      }
    });
    ref.listen(webDavConnectionsProvider, (_, __) {
      if (!mounted) return;
      setState(_pruneStaleShells);
    });

    final selectedId = widget.connection?.id;
    if (selectedId == null || _materializedShells.isEmpty) {
      return const SizedBox.shrink();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        for (final conn in _materializedShells.values)
          Offstage(
            offstage: conn.id != selectedId,
            child: WebDavShellScreen(
              key: ValueKey('webdav_shell_${conn.id}'),
              connection: conn,
              embedded: widget.embedded,
              onBack: widget.onBack,
            ),
          ),
      ],
    );
  }
}
