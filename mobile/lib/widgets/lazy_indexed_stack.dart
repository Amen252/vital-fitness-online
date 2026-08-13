import 'package:flutter/material.dart';

/// Like [IndexedStack], but only builds a child the first time it becomes active.
/// Inactive never-visited tabs stay as empty placeholders so their [State.initState]
/// (and API fetches) do not run until the user opens them.
class LazyIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final AlignmentGeometry alignment;
  final TextDirection? textDirection;
  final StackFit sizing;

  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.alignment = AlignmentDirectional.topStart,
    this.textDirection,
    this.sizing = StackFit.loose,
  });

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  late final List<bool> _activated;

  @override
  void initState() {
    super.initState();
    _activated = List<bool>.filled(widget.children.length, false);
    _activate(widget.index);
  }

  @override
  void didUpdateWidget(covariant LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.children.length != _activated.length) {
      final next = List<bool>.filled(widget.children.length, false);
      for (var i = 0; i < next.length && i < _activated.length; i++) {
        next[i] = _activated[i];
      }
      _activated
        ..clear()
        ..addAll(next);
    }
    _activate(widget.index);
  }

  void _activate(int index) {
    if (index < 0 || index >= _activated.length) return;
    if (!_activated[index]) {
      _activated[index] = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index.clamp(0, widget.children.length - 1),
      alignment: widget.alignment,
      textDirection: widget.textDirection,
      sizing: widget.sizing,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          _activated[i] ? widget.children[i] : const SizedBox.shrink(),
      ],
    );
  }
}
