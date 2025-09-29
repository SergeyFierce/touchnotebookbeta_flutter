import 'package:flutter/material.dart';

import '../services/app_settings.dart';

class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  Alignment _focusAlignment = const Alignment(-0.9, -0.4);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = AppSettingsScope.of(context);
    final alignment = _alignmentForMode(settings.themeMode);
    if (_focusAlignment != alignment) {
      _focusAlignment = alignment;
    }
  }

  Alignment _alignmentForMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return const Alignment(0.9, -0.4);
      case ThemeMode.light:
        return const Alignment(-0.9, -0.4);
      case ThemeMode.system:
        final brightness = MediaQuery.maybeOf(context)?.platformBrightness;
        if (brightness == Brightness.dark) {
          return const Alignment(0.9, -0.4);
        }
        return const Alignment(-0.9, -0.4);
    }
  }

  Future<void> _onSelect(ThemeMode mode) async {
    final settings = AppSettingsScope.of(context);
    await settings.setThemeMode(mode);
    if (!mounted) return;
    setState(() {
      _focusAlignment = _alignmentForMode(mode);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Тема')),
      body: AnimatedBuilder(
        animation: settings,
        builder: (context, _) {
          final mode = settings.themeMode;
          final effectiveMode = mode == ThemeMode.system
              ? (MediaQuery.of(context).platformBrightness == Brightness.dark
                  ? ThemeMode.dark
                  : ThemeMode.light)
              : mode;

          final highlightColor = effectiveMode == ThemeMode.dark
              ? Colors.indigo.shade700.withOpacity(0.6)
              : Colors.amber.shade200.withOpacity(0.7);

          return Stack(
            children: [
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: _focusAlignment,
                      radius: 1.2,
                      colors: [
                        highlightColor,
                        colorScheme.surface,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Выберите оформление приложения',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _ThemeOptionCard(
                            title: 'Дневная тема',
                            description: 'Яркая палитра и светлый фон.',
                            icon: Icons.wb_sunny_rounded,
                            selected: effectiveMode == ThemeMode.light,
                            onTap: () => _onSelect(ThemeMode.light),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ThemeOptionCard(
                            title: 'Ночная тема',
                            description: 'Глубокие тона и мягкий контраст.',
                            icon: Icons.nights_stay_rounded,
                            selected: effectiveMode == ThemeMode.dark,
                            onTap: () => _onSelect(ThemeMode.dark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  effectiveMode == ThemeMode.dark
                                      ? Icons.dark_mode_outlined
                                      : Icons.light_mode_outlined,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    effectiveMode == ThemeMode.dark
                                        ? 'Активна ночная тема'
                                        : 'Активна дневная тема',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              effectiveMode == ThemeMode.dark
                                  ? 'Ночная тема снижает нагрузку на глаза и экономит заряд батареи в условиях слабого освещения.'
                                  : 'Дневная тема подчёркивает детали интерфейса и обеспечивает максимальную читаемость в светлых условиях.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  const _ThemeOptionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderRadius = BorderRadius.circular(20);

    return Card(
      elevation: selected ? 4 : 0,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            color: selected
                ? colorScheme.primaryContainer.withOpacity(0.55)
                : colorScheme.surface,
            border: Border.all(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 48,
                color: selected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    selected ? 'Выбрано' : 'Выбрать',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: selected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.primary,
                    ),
                  ),
                  Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    color: selected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
