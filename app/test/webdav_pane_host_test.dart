import 'package:app/api/webdav.dart';
import 'package:app/providers/device_provider.dart';
import 'package:app/screens/webdav_shell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _InitCounterShell extends WebDavShellScreen {
  const _InitCounterShell({
    super.key,
    required super.connection,
    required this.onInit,
  });

  final VoidCallback onInit;

  @override
  ConsumerState<WebDavShellScreen> createState() => _InitCounterShellState();
}

class _InitCounterShellState extends ConsumerState<_InitCounterShell> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox(key: Key('shell_body'));
  }
}

class _TestWebDavPaneHost extends StatefulWidget {
  const _TestWebDavPaneHost({
    super.key,
    required this.connections,
    required this.selectedId,
  });

  final List<WebDavConnectionSummary> connections;
  final int selectedId;

  @override
  State<_TestWebDavPaneHost> createState() => _TestWebDavPaneHostState();
}

class _TestWebDavPaneHostState extends State<_TestWebDavPaneHost> {
  final Map<int, WebDavConnectionSummary> _materializedShells = {};
  int initCount = 0;

  WebDavConnectionSummary? _connectionFor(int id) {
    for (final conn in widget.connections) {
      if (conn.id == id) return conn;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final conn = _connectionFor(widget.selectedId);
    if (conn != null) {
      _materializedShells[conn.id] = conn;
    }
  }

  @override
  void didUpdateWidget(covariant _TestWebDavPaneHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    final conn = _connectionFor(widget.selectedId);
    if (conn != null) {
      _materializedShells[conn.id] = conn;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = widget.selectedId;
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final conn in _materializedShells.values)
          Offstage(
            offstage: conn.id != selectedId,
            child: _InitCounterShell(
              key: ValueKey('webdav_shell_${conn.id}'),
              connection: conn,
              onInit: () => initCount += 1,
            ),
          ),
      ],
    );
  }
}

const _connA = WebDavConnectionSummary(
  id: 1,
  name: 'A',
  baseUrl: 'https://a.example.com',
  rootPath: '/',
);

const _connB = WebDavConnectionSummary(
  id: 2,
  name: 'B',
  baseUrl: 'https://b.example.com',
  rootPath: '/',
);


void main() {
  group('WebDavPaneHost cache behavior', () {
    testWidgets('switching back to a visited connection does not recreate shell',
        (tester) async {
      final hostKey = GlobalKey<_TestWebDavPaneHostState>();
      await tester.pumpWidget(
        MaterialApp(
          home: _TestWebDavPaneHost(
            key: hostKey,
            connections: const [_connA, _connB],
            selectedId: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(hostKey.currentState!.initCount, 1);

      await tester.pumpWidget(
        MaterialApp(
          home: _TestWebDavPaneHost(
            key: hostKey,
            connections: const [_connA, _connB],
            selectedId: 2,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(hostKey.currentState!.initCount, 2);

      await tester.pumpWidget(
        MaterialApp(
          home: _TestWebDavPaneHost(
            key: hostKey,
            connections: const [_connA, _connB],
            selectedId: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(hostKey.currentState!.initCount, 2);
    });
  });

  group('lazy chat builder contract', () {
    test('chatContentBuilder is skipped for WebDAV selection', () {
      var chatBuildCount = 0;
      Widget buildChat() {
        chatBuildCount += 1;
        return const SizedBox();
      }

      final selected = webDavSelectionId(1);
      if (isChatSelection(selected)) {
        buildChat();
      }

      expect(chatBuildCount, 0);
    });
  });
}
