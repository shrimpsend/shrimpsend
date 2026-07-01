import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors [ChatSessionPaneHost] Offstage + ValueKey + per-session builder.
class _TestChatSessionPaneHost extends StatefulWidget {
  const _TestChatSessionPaneHost({
    super.key,
    required this.selectedDeviceId,
    required this.chatContentBuilder,
  });

  final String selectedDeviceId;
  final Widget Function(String sessionId) chatContentBuilder;

  @override
  State<_TestChatSessionPaneHost> createState() =>
      _TestChatSessionPaneHostState();
}

class _TestChatSessionPaneHostState extends State<_TestChatSessionPaneHost> {
  final List<String> _materializedSessionIds = <String>[];

  @override
  void initState() {
    super.initState();
    _materialize(widget.selectedDeviceId);
  }

  @override
  void didUpdateWidget(covariant _TestChatSessionPaneHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _materialize(widget.selectedDeviceId);
  }

  void _materialize(String sessionId) {
    if (_materializedSessionIds.contains(sessionId)) return;
    _materializedSessionIds.add(sessionId);
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = widget.selectedDeviceId;
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final sessionId in _materializedSessionIds)
          Offstage(
            offstage: sessionId != selectedId,
            child: KeyedSubtree(
              key: ValueKey('chat_session_$sessionId'),
              child: widget.chatContentBuilder(sessionId),
            ),
          ),
      ],
    );
  }
}

class _Harness extends StatefulWidget {
  const _Harness({super.key, required this.initialSessionId});

  final String initialSessionId;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSessionId;
  }

  void select(String sessionId) => setState(() => _selected = sessionId);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: _TestChatSessionPaneHost(
          key: const ValueKey('chat_session_pane_host'),
          selectedDeviceId: _selected,
          chatContentBuilder: (sessionId) => Column(
            children: [
              Expanded(child: Text('messages-$sessionId')),
              TextField(key: ValueKey('composer_$sessionId')),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  group('Chat session pane switching', () {
    testWidgets('A→B→A keeps visible pane composer interactable', (tester) async {
      final harnessKey = GlobalKey<_HarnessState>();
      await tester.pumpWidget(
        _Harness(key: harnessKey, initialSessionId: 'peer-a'),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('composer_peer-a')), findsOneWidget);

      harnessKey.currentState!.select('peer-b');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('composer_peer-b')), findsOneWidget);

      harnessKey.currentState!.select('peer-a');
      await tester.pumpAndSettle();

      final composerA = find.byKey(const ValueKey('composer_peer-a'));
      expect(composerA, findsOneWidget);
      await tester.enterText(composerA, 'hello');
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('each materialized session keeps independent subtree',
        (tester) async {
      final harnessKey = GlobalKey<_HarnessState>();
      await tester.pumpWidget(
        _Harness(key: harnessKey, initialSessionId: 'peer-a'),
      );
      await tester.pumpAndSettle();

      harnessKey.currentState!.select('peer-b');
      await tester.pumpAndSettle();

      expect(find.text('messages-peer-a', skipOffstage: false), findsOneWidget);
      expect(find.text('messages-peer-b', skipOffstage: false), findsOneWidget);
      expect(
        find.byKey(const ValueKey('chat_session_peer-a'), skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('chat_session_peer-b'), skipOffstage: false),
        findsOneWidget,
      );
    });
  });
}
