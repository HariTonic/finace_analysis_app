import 'package:flutter/material.dart';

class RunningText extends StatefulWidget {
  const RunningText(
    this.text, {
    super.key,
    required this.style,
    this.maxWidth,
    this.gap = 28,
    this.velocity = 28,
    this.textAlign = TextAlign.start,
  });

  final String text;
  final TextStyle style;
  final double? maxWidth;
  final double gap;
  final double velocity;
  final TextAlign textAlign;

  @override
  State<RunningText> createState() => _RunningTextState();
}

class _RunningTextState extends State<RunningText> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = widget.maxWidth ?? constraints.maxWidth;
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();

        final textWidth = textPainter.width;
        if (availableWidth.isInfinite || textWidth <= availableWidth) {
          _controller.stop();
          return Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.visible,
            textAlign: widget.textAlign,
            style: widget.style,
          );
        }

        final travelDistance = textWidth + widget.gap;
        final durationMs = (travelDistance / widget.velocity * 1000).round().clamp(2500, 18000);
        if (_controller.duration?.inMilliseconds != durationMs || !_controller.isAnimating) {
          _controller
            ..duration = Duration(milliseconds: durationMs)
            ..repeat();
        }

        return ClipRect(
          child: SizedBox(
            width: availableWidth,
            height: textPainter.height,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final offset = -travelDistance * _controller.value;
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: Row(
                    children: [
                      Text(widget.text, style: widget.style, maxLines: 1),
                      SizedBox(width: widget.gap),
                      Text(widget.text, style: widget.style, maxLines: 1),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
