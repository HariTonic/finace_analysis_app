import 'package:flutter/material.dart';

class ScrollShadowWrapper extends StatefulWidget {
  final Widget Function(ScrollController controller) builder;

  const ScrollShadowWrapper({
    super.key,
    required this.builder,
  });

  @override
  State<ScrollShadowWrapper> createState() => _ScrollShadowWrapperState();
}

class _ScrollShadowWrapperState extends State<ScrollShadowWrapper> {
  late final ScrollController _controller;
  bool _showTopShadow = false;
  bool _showBottomShadow = false;
  bool _showScrollToTopButton = false;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    _controller.addListener(_updateScrollState);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollState());
  }

  void _updateScrollState() {
    if (!_controller.hasClients) {
      return;
    }

    final offset = _controller.offset;
    final maxScroll = _controller.position.maxScrollExtent;
    final canScrollUp = offset > 12;
    final canScrollDown = offset < maxScroll - 12;
    final showButton = offset > 260;

    if (canScrollUp != _showTopShadow ||
        canScrollDown != _showBottomShadow ||
        showButton != _showScrollToTopButton) {
      setState(() {
        _showTopShadow = canScrollUp;
        _showBottomShadow = canScrollDown;
        _showScrollToTopButton = showButton;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_updateScrollState);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.axis == Axis.vertical) {
              _updateScrollState();
            }
            return false;
          },
          child: widget.builder(_controller),
        ),
        if (_showTopShadow)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 18,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (_showBottomShadow)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 18,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (_showScrollToTopButton)
          Positioned(
            bottom: 18,
            right: 18,
            child: ElevatedButton(
              onPressed: () {
                _controller.animateTo(
                  0,
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOut,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5D6CFF),
                elevation: 8,
                shadowColor: Colors.black45,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.arrow_upward, size: 18, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Top',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
