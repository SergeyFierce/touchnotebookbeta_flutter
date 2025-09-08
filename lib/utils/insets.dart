import 'dart:math' as math;
import 'package:flutter/widgets.dart';

double safeBottom(BuildContext context, {double extra = 0}) =>
    MediaQuery.of(context).viewPadding.bottom + extra;

double liftedBottom(BuildContext context, {double extra = 0}) {
  final insets = MediaQuery.of(context);
  return math.max(insets.viewInsets.bottom, insets.viewPadding.bottom) + extra;
}
