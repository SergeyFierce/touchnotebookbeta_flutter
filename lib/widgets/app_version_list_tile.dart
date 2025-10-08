import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Универсальная плитка с информацией о версии приложения.
class AppVersionListTile extends StatelessWidget {
  const AppVersionListTile({super.key, this.icon});

  /// Опциональная иконка слева от текста.
  final IconData? icon;

  static final Future<PackageInfo> _packageInfoFuture =
      PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final IconData leadingIcon = icon ?? Icons.verified_outlined;

    return FutureBuilder<PackageInfo>(
      future: _packageInfoFuture,
      builder: (context, snapshot) {
        final textTheme = Theme.of(context).textTheme;
        final subtitleStyle = textTheme.bodyMedium;

        String subtitle;
        if (snapshot.connectionState == ConnectionState.waiting) {
          subtitle = 'Загрузка…';
        } else if (snapshot.hasError) {
          subtitle = 'Недоступно';
        } else if (snapshot.hasData) {
          final info = snapshot.data!;
          subtitle = '${info.version} (сборка ${info.buildNumber})';
        } else {
          subtitle = 'Недоступно';
        }

        return ListTile(
          leading: Icon(leadingIcon),
          title: const Text('Версия приложения'),
          subtitle: Text(subtitle, style: subtitleStyle),
        );
      },
    );
  }
}
