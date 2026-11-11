import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/widgets/player_view_gate.dart';

void main() {
  testWidgets('does not create the video or controls before readiness',
      (tester) async {
    var videoBuilds = 0;
    var refreshes = 0;
    var returns = 0;
    await tester.pumpWidget(MaterialApp(
      home: PlayerViewGate(
        ready: false,
        readyBuilder: (_) {
          videoBuilds++;
          throw StateError('The native video must remain uninitialized');
        },
        waitingBuilder: (_) => Scaffold(
          body: Column(
            children: [
              const Text('Waiting for the previous room to close'),
              TextButton(
                onPressed: () => refreshes++,
                child: const Text('Refresh'),
              ),
              TextButton(
                onPressed: () => returns++,
                child: const Text('Return'),
              ),
            ],
          ),
        ),
      ),
    ));

    expect(videoBuilds, 0);
    await tester.tap(find.text('Refresh'));
    await tester.tap(find.text('Return'));
    expect(refreshes, 1);
    expect(returns, 1);
    expect(videoBuilds, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mounts only when ready and unmounts when the owner closes',
      (tester) async {
    var videoBuilds = 0;
    var mounts = 0;
    var disposals = 0;
    Widget page(bool ready) => MaterialApp(
          home: PlayerViewGate(
            ready: ready,
            readyBuilder: (_) {
              videoBuilds++;
              return _VideoProbe(
                onMount: () => mounts++,
                onDispose: () => disposals++,
              );
            },
            waitingBuilder: (_) => const Text('Waiting'),
          ),
        );

    await tester.pumpWidget(page(false));
    expect(videoBuilds, 0);
    expect(mounts, 0);
    await tester.pumpWidget(page(true));
    expect(videoBuilds, 1);
    expect(mounts, 1);
    expect(find.text('Video and controls'), findsOneWidget);
    await tester.pumpWidget(page(false));
    expect(videoBuilds, 1);
    expect(disposals, 1);
    expect(find.text('Video and controls'), findsNothing);
    await tester.pumpWidget(page(false));
    expect(videoBuilds, 1);
    expect(disposals, 1);
  });
}

class _VideoProbe extends StatefulWidget {
  final VoidCallback onMount;
  final VoidCallback onDispose;

  const _VideoProbe({required this.onMount, required this.onDispose});

  @override
  State<_VideoProbe> createState() => _VideoProbeState();
}

class _VideoProbeState extends State<_VideoProbe> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Text('Video and controls');
}
