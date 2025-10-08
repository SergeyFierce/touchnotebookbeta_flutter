import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Маршрут с анимацией радиального раскрытия (circular reveal).
class CircularRevealPageRoute<T> extends PageRouteBuilder<T> {
  CircularRevealPageRoute({
    required WidgetBuilder builder,
    required this.center,
    Duration duration = const Duration(milliseconds: 520),
    this.curve = Curves.easeOutCubic,
    this.reverseCurve = Curves.easeInCubic,
    RouteSettings? settings,
  })  : super(
          settings: settings,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
        );
  final Offset center;
  final Curve curve;
  final Curve reverseCurve;

  static Offset originFromContext(BuildContext context) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) {
      return _centerOf(context);
    }

    final overlay = Navigator.of(context).overlay?.context.findRenderObject();
    if (overlay is! RenderBox) {
      return _centerOf(context);
    }

    return renderObject.localToGlobal(
      renderObject.size.center(Offset.zero),
      ancestor: overlay,
    );
  }

  static Offset _centerOf(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Offset(size.width / 2, size.height / 2);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: curve,
      reverseCurve: reverseCurve,
    );

    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        final size = MediaQuery.of(context).size;
        return ClipPath(
          clipper: _CircularRevealClipper(
            progress: curved.value,
            center: center,
            size: size,
          ),
          child: child,
        );
      },
      child: child,
    );
  }
}

class _CircularRevealClipper extends CustomClipper<Path> {
  _CircularRevealClipper({
    required this.progress,
    required this.center,
    required this.size,
  });

  final double progress;
  final Offset center;
  final Size size;

  @override
  Path getClip(Size clipSize) {
    final radius = _maxRadius(size, center) * progress;
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(_CircularRevealClipper oldClipper) {
    return oldClipper.progress != progress ||
        oldClipper.center != center ||
        oldClipper.size != size;
  }

  static double _maxRadius(Size size, Offset center) {
    final distances = <double>[
      (center - const Offset(0, 0)).distance,
      (center - Offset(size.width, 0)).distance,
      (center - Offset(0, size.height)).distance,
      (center - Offset(size.width, size.height)).distance,
    ];
    return distances.reduce(math.max);
  }
}
