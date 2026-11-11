import 'package:flutter/widgets.dart';

/// Defers creation of the native video subtree until its owner is ready.
/// Keep native player/controller reads inside [readyBuilder], not its arguments.
class PlayerViewGate extends StatelessWidget {
  final bool ready;
  final WidgetBuilder readyBuilder;
  final WidgetBuilder waitingBuilder;

  const PlayerViewGate({
    required this.ready,
    required this.readyBuilder,
    required this.waitingBuilder,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ready ? readyBuilder(context) : waitingBuilder(context);
  }
}
