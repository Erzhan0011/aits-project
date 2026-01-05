import 'package:flutter/material.dart';

class TiltWidget extends StatefulWidget {
  final Widget child;
  final double maxTilt;

  const TiltWidget({
    super.key,
    required this.child,
    this.maxTilt = 0.1,
  });

  @override
  State<TiltWidget> createState() => _TiltWidgetState();
}

class _TiltWidgetState extends State<TiltWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final ValueNotifier<Offset> _tiltNotifier = ValueNotifier<Offset>(Offset.zero);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _tiltNotifier.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            _controller.forward();
          },
          onPointerMove: (event) {
            _tiltNotifier.value = Offset(
              (event.localPosition.dy / constraints.maxHeight) - 0.5,
              (event.localPosition.dx / constraints.maxWidth) - 0.5,
            );
          },
          onPointerUp: (event) {
            _controller.reverse();
            _tiltNotifier.value = Offset.zero;
          },
          onPointerCancel: (event) {
            _controller.reverse();
            _tiltNotifier.value = Offset.zero;
          },
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return ValueListenableBuilder<Offset>(
                valueListenable: _tiltNotifier,
                builder: (context, tilt, child) {
                  return Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001) // perspective
                      ..rotateX(tilt.dx * widget.maxTilt)
                      ..rotateY(-tilt.dy * widget.maxTilt)
                      ..scale(_animation.value),
                    alignment: FractionalOffset.center,
                    child: child,
                  );
                },
                child: child,
              );
            },
            child: widget.child,
          ),
        );
      },
    );
  }
}
