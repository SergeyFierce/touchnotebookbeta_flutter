import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

enum SystemNotificationStyle { info, success, warning, error }

OverlaySupportEntry showSystemNotification(
  String message, {
  SystemNotificationStyle style = SystemNotificationStyle.info,
  Duration duration = const Duration(seconds: 3),
  String? actionLabel,
  Future<void> Function()? onAction,
  IconData? iconOverride,
}) {
  return showOverlayNotification(
    (context) {
      final entry = OverlaySupportEntry.of(context);
      final colors = _resolveColors(style, Theme.of(context));
      final icon = iconOverride ?? colors.icon;
      final action = (actionLabel != null && onAction != null)
          ? TextButton(
              onPressed: () async {
                entry?.dismiss();
                await onAction();
              },
              style: TextButton.styleFrom(
                foregroundColor: colors.foreground,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              child: Text(actionLabel),
            )
          : null;

      return _SystemNotificationSurface(
        backgroundColor: colors.background,
        textColor: colors.foreground,
        icon: icon,
        iconColor: colors.iconColor,
        content: Text(
          message,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        action: action,
      );
    },
    duration: duration,
  );
}

OverlaySupportEntry showInfoBanner(
  String message, {
  Duration duration = const Duration(seconds: 3),
}) =>
    showSystemNotification(
      message,
      style: SystemNotificationStyle.info,
      duration: duration,
    );

OverlaySupportEntry showSuccessBanner(
  String message, {
  Duration duration = const Duration(seconds: 3),
}) =>
    showSystemNotification(
      message,
      style: SystemNotificationStyle.success,
      duration: duration,
    );

OverlaySupportEntry showWarningBanner(
  String message, {
  Duration duration = const Duration(seconds: 3),
}) =>
    showSystemNotification(
      message,
      style: SystemNotificationStyle.warning,
      duration: duration,
    );

OverlaySupportEntry showErrorBanner(
  String message, {
  Duration duration = const Duration(seconds: 4),
}) =>
    showSystemNotification(
      message,
      style: SystemNotificationStyle.error,
      duration: duration,
    );

OverlaySupportEntry showUndoBanner({
  required String message,
  required Duration duration,
  required Future<void> Function() onUndo,
  IconData icon = Icons.undo,
  SystemNotificationStyle style = SystemNotificationStyle.warning,
  String actionLabel = 'Отменить',
}) {
  final endTime = DateTime.now().add(duration);
  return showOverlayNotification(
    (context) {
      final entry = OverlaySupportEntry.of(context);
      final colors = _resolveColors(style, Theme.of(context));
      return _SystemNotificationSurface(
        backgroundColor: colors.background,
        textColor: colors.foreground,
        icon: icon,
        iconColor: colors.iconColor,
        content: UndoCountdownContent(
          message: message,
          endTime: endTime,
          duration: duration,
          progressColor: colors.iconColor,
          trackColor: colors.foreground.withOpacity(0.2),
        ),
        action: TextButton(
          onPressed: () async {
            entry?.dismiss();
            await onUndo();
          },
          style: TextButton.styleFrom(
            foregroundColor: colors.foreground,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
          child: Text(actionLabel),
        ),
      );
    },
    duration: duration,
  );
}

class UndoCountdownContent extends StatefulWidget {
  final String message;
  final DateTime endTime;
  final Duration duration;
  final Color? progressColor;
  final Color? trackColor;

  const UndoCountdownContent({
    super.key,
    required this.message,
    required this.endTime,
    required this.duration,
    this.progressColor,
    this.trackColor,
  });

  @override
  State<UndoCountdownContent> createState() => _UndoCountdownContentState();
}

class _UndoCountdownContentState extends State<UndoCountdownContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  double _fractionRemaining(DateTime now) {
    final total = widget.duration.inMilliseconds;
    if (total <= 0) return 0;
    final left = widget.endTime.difference(now).inMilliseconds;
    if (left <= 0) return 0;
    return (left / total).clamp(0.0, 1.0);
  }

  void _syncAndRun() {
    final now = DateTime.now();
    final fraction = _fractionRemaining(now);
    final remainingMs = (widget.duration.inMilliseconds * fraction).round();

    _controller.stop();
    _controller.value = fraction;
    if (remainingMs > 0) {
      _controller.animateTo(
        0.0,
        duration: Duration(milliseconds: remainingMs),
        curve: Curves.linear,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      value: 1.0,
      lowerBound: 0.0,
      upperBound: 1.0,
    )..addListener(() {
        if (mounted) setState(() {});
      });
    _syncAndRun();
  }

  @override
  void didUpdateWidget(covariant UndoCountdownContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endTime != widget.endTime ||
        oldWidget.duration != widget.duration) {
      _syncAndRun();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.value;
    final secondsLeft = (value * widget.duration.inSeconds).ceil().clamp(0, 999);
    final progressColor = widget.progressColor ?? Theme.of(context).colorScheme.primary;
    final trackColor = widget.trackColor ?? progressColor.withOpacity(0.2);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(widget.message)),
            Text('$secondsLeft c'),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 4,
            color: progressColor,
            backgroundColor: trackColor,
          ),
        ),
      ],
    );
  }
}

class _SystemNotificationSurface extends StatelessWidget {
  final Widget content;
  final IconData? icon;
  final Color? iconColor;
  final Color backgroundColor;
  final Color textColor;
  final Widget? action;

  const _SystemNotificationSurface({
    required this.content,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
    this.iconColor,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14);
    final textStyle = baseStyle.copyWith(color: textColor);

    final children = <Widget>[];
    if (icon != null) {
      children
        ..add(Icon(icon, color: iconColor ?? textColor))
        ..add(const SizedBox(width: 12));
    }
    children.add(Expanded(child: content));
    if (action != null) {
      children
        ..add(const SizedBox(width: 12))
        ..add(action!);
    }

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.transparent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: DefaultTextStyle(
                style: textStyle,
                child: IconTheme.merge(
                  data: IconThemeData(color: iconColor ?? textColor),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: children,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SystemNotificationColors {
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color iconColor;

  const _SystemNotificationColors({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.iconColor,
  });
}

_SystemNotificationColors _resolveColors(
  SystemNotificationStyle style,
  ThemeData theme,
) {
  final scheme = theme.colorScheme;
  switch (style) {
    case SystemNotificationStyle.success:
      return _SystemNotificationColors(
        icon: Icons.check_circle_outline,
        background: scheme.primaryContainer,
        foreground: scheme.onPrimaryContainer,
        iconColor: scheme.onPrimaryContainer,
      );
    case SystemNotificationStyle.warning:
      return _SystemNotificationColors(
        icon: Icons.warning_amber_rounded,
        background: scheme.tertiaryContainer,
        foreground: scheme.onTertiaryContainer,
        iconColor: scheme.onTertiaryContainer,
      );
    case SystemNotificationStyle.error:
      return _SystemNotificationColors(
        icon: Icons.error_outline,
        background: scheme.errorContainer,
        foreground: scheme.onErrorContainer,
        iconColor: scheme.onErrorContainer,
      );
    case SystemNotificationStyle.info:
    default:
      return _SystemNotificationColors(
        icon: Icons.info_outline,
        background: scheme.surface,
        foreground: scheme.onSurface,
        iconColor: scheme.primary,
      );
  }
}
