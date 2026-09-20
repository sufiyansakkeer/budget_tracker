import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

import '../constants/app_motion.dart';
import 'rive_file_cache.dart';
import 'rive_icon_spec.dart';

/// A single animated navigation icon.
///
/// This is the only file in the app that imports `package:rive`. It owns the
/// artboard instance and its [StateMachineController], tints the artwork with
/// [color] and plays the icon's "active" animation as a short **pulse** each
/// time [selected] becomes true or [pulseToken] changes while selected.
///
/// The steady selected/unselected look is *not* Rive state: the bar draws it
/// (indicator, tint, label). That keeps the icon correct after navigation,
/// returning from other screens and a cold start, and it works for artboards
/// whose "active" animation loops while the input is held.
///
/// While the file loads, or if it cannot be loaded, [fallback] is shown.
class RiveNavIcon extends StatefulWidget {
  final RiveIconSpec spec;
  final Color color;
  final double size;
  final bool selected;

  /// Change this value to replay the pulse on an already-selected icon
  /// (e.g. the user re-tapped the current tab).
  final int pulseToken;

  /// When true the artboard is rendered at idle and never pulsed.
  final bool reduceMotion;

  final Widget fallback;

  const RiveNavIcon({
    super.key,
    required this.spec,
    required this.color,
    required this.size,
    required this.selected,
    required this.pulseToken,
    required this.reduceMotion,
    required this.fallback,
  });

  @override
  State<RiveNavIcon> createState() => _RiveNavIconState();
}

class _RiveNavIconState extends State<RiveNavIcon> {
  Artboard? _artboard;
  StateMachineController? _controller;
  SMIInput<bool>? _input;
  bool _failed = false;
  Timer? _pulseTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final file = await RiveFileCache.load(widget.spec.asset);
      final source = file.artboardByName(widget.spec.artboard);
      if (source == null) throw StateError('Artboard ${widget.spec.artboard}');
      final artboard = source.instance();
      final controller = StateMachineController.fromArtboard(
        artboard,
        widget.spec.stateMachine,
      );
      if (controller == null) {
        throw StateError('State machine ${widget.spec.stateMachine}');
      }
      artboard.addController(controller);
      final input = controller.findInput<bool>(widget.spec.input);
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _artboard = artboard;
        _controller = controller;
        _input = input;
      });
    } catch (error) {
      // Never let a missing/broken asset take the navigation bar down: the
      // Material glyph is shown instead and the cause is logged once.
      debugPrint(
        'RiveNavIcon: ${widget.spec.artboard} unavailable, '
        'using Material icon ($error)',
      );
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void didUpdateWidget(covariant RiveNavIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    final becameSelected = widget.selected && !oldWidget.selected;
    final replay = widget.selected && widget.pulseToken != oldWidget.pulseToken;
    if (becameSelected || replay) _pulse();
  }

  /// Plays the "active" animation once. The input is released after
  /// [AppMotion.emphasized] so looping artboards settle back to idle.
  void _pulse() {
    final input = _input;
    if (input == null || widget.reduceMotion) return;
    _pulseTimer?.cancel();
    input.value = true;
    _pulseTimer = Timer(AppMotion.emphasized, () {
      if (mounted) input.value = false;
    });
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final artboard = _artboard;
    if (artboard == null || _failed) {
      return widget.fallback;
    }
    return ExcludeSemantics(
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(widget.color, BlendMode.srcIn),
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Transform.scale(
            scale: widget.spec.scale,
            child: Rive(artboard: artboard, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
