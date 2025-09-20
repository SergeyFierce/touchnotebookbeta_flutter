import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'add_contact_screen.dart';
import 'settings_screen.dart';
import 'contact_list_screen.dart';
import '../services/contact_database.dart';

/// ---------------------
/// Строки (русская локаль)
/// ---------------------
abstract class R {
  static const appTitle = 'Touch NoteBook';
  static const homeTitle = 'Главный экран';
  static const settings = 'Настройки';
  static const support = 'Поддержка';
  static const addContact = 'Добавить контакт';
  static const contactSaved = 'Контакт сохранён';
  static const noContacts = 'Пока нет контактов';
  static const noData = 'Нет данных';
  static const loadError = 'Не удалось загрузить данные';
  static const tryAgain = 'Повторить';
  static const checkNetwork = 'Проверьте подключение к сети и попробуйте ещё раз.';
  static const telegramNotInstalled = 'Telegram не установлен, откроем в браузере';
  static const telegramOpenFailed = 'Не удалось открыть Telegram';
  static const loading = 'Загрузка…';
  static const unknown = 'Неизвестно';
  static const qtyLabel = 'Количество';
  static const summaryTitle = 'Сводка по контактам';
  static const summaryKnownLabel = 'Всего известных контактов';
  static const summaryAllKnown = 'Все категории синхронизированы';
  static const quickActions = 'Быстрые действия';

  static String summaryUnknown(int count) {
    if (count <= 0) return summaryAllKnown;
    final noun = (count == 1) ? 'категории' : 'категориям';
    return 'По $count\u00A0$noun пока нет данных';
  }
}

/// ---------------------
/// Константы оформления
/// ---------------------
const kPad16 = EdgeInsets.all(16);
const kGap6 = SizedBox(height: 6);
const kGap8 = SizedBox(height: 8);
const kGap12 = SizedBox(height: 12);
const kGap16w = SizedBox(width: 16);
const kDurTap = Duration(milliseconds: 90);
const kDurFast = Duration(milliseconds: 200);
const kBr16 = BorderRadius.all(Radius.circular(16));

EdgeInsets _listPadding(BuildContext context) {
  final mediaQuery = MediaQuery.of(context);
  const fabEstimatedHeight = 56.0; // оценка высоты FAB.extended
  final bottom = 16 +
      mediaQuery.viewPadding.bottom +
      kFloatingActionButtonMargin +
      fabEstimatedHeight;
  return EdgeInsets.fromLTRB(16, 16, 16, bottom);
}

/// ---------------------
/// Типобезопасные категории
/// ---------------------
enum ContactCategory { partner, client, prospect }

extension ContactCategoryX on ContactCategory {
  String get dbKey => switch (this) {
    ContactCategory.partner => 'Партнёр',
    ContactCategory.client => 'Клиент',
    ContactCategory.prospect => 'Потенциальный',
  };

  String get titlePlural => switch (this) {
    ContactCategory.partner => 'Партнёры',
    ContactCategory.client => 'Клиенты',
    ContactCategory.prospect => 'Потенциальные клиенты',
  };

  IconData get icon => switch (this) {
    ContactCategory.partner => Icons.handshake,
    ContactCategory.client => Icons.people,
    ContactCategory.prospect => Icons.person_add_alt_1,
  };

  /// Склонение + неразрывный пробел
  String russianCount(int count) {
    if (count == 0) {
      return switch (this) {
        ContactCategory.partner => 'Нет партнёров',
        ContactCategory.client => 'Нет клиентов',
        ContactCategory.prospect => 'Нет потенциальных клиентов',
      };
    }
    final m10 = count % 10;
    final m100 = count % 100;

    String pick({required String one, required String few, required String many}) {
      final word = (m10 == 1 && m100 != 11)
          ? one
          : (m10 >= 2 && m10 <= 4 && (m100 < 10 || m100 >= 20))
          ? few
          : many;
      return '$count\u00A0$word';
    }

    return switch (this) {
      ContactCategory.partner => pick(one: 'партнёр', few: 'партнёра', many: 'партнёров'),
      ContactCategory.client => pick(one: 'клиент', few: 'клиента', many: 'клиентов'),
      ContactCategory.prospect =>
          pick(one: 'потенциальный клиент', few: 'потенциальных клиента', many: 'потенциальных клиентов'),
    };
  }
}

/// ---------------------
/// Типобезопасные счётчики
/// ---------------------
class Counts {
  final Map<ContactCategory, int> _m;
  const Counts(this._m);

  int of(ContactCategory c) => _m[c] ?? 0;

  bool get allZero => ContactCategory.values.every((c) => of(c) == 0);

  int get knownTotal {
    return ContactCategory.values.fold<int>(0, (sum, c) {
      final value = of(c);
      return value >= 0 ? sum + value : sum;
    });
  }

  int get unknownCount =>
      ContactCategory.values.where((c) => of(c) < 0).length;
}

/// ---------------------
/// Экран
/// ---------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<Counts> _countsFuture;
  late final VoidCallback _revListener;
  bool _loadErrorShown = false;

  @override
  void initState() {
    super.initState();
    _countsFuture = _loadCounts();
    _revListener = _refresh;
    ContactDatabase.instance.revision.addListener(_revListener);
  }

  @override
  void dispose() {
    ContactDatabase.instance.revision.removeListener(_revListener);
    super.dispose();
  }

  Future<int> _safe(Future<int> f) async {
    try {
      return await f;
    } catch (e, s) {
      debugPrint('count error: $e\n$s');
      return -1; // -1 = неизвестно
    }
  }

  Future<Counts> _loadCounts() async {
    final partner = await _safe(ContactDatabase.instance.countByCategory(ContactCategory.partner.dbKey));
    final client = await _safe(ContactDatabase.instance.countByCategory(ContactCategory.client.dbKey));
    final prospect = await _safe(ContactDatabase.instance.countByCategory(ContactCategory.prospect.dbKey));
    return Counts({
      ContactCategory.partner: partner,
      ContactCategory.client: client,
      ContactCategory.prospect: prospect,
    });
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _countsFuture = _loadCounts();
    });
  }

  void _showLoadErrorOnce(BuildContext context) {
    if (_loadErrorShown) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(R.loadError)),
      );
    });
    _loadErrorShown = true;
  }

  Future<void> _openSupport(BuildContext context) async {
    const group = 'touchnotebook';
    final tgUri = Uri.parse('tg://resolve?domain=$group');
    final webUri = Uri.parse('https://t.me/$group');
    try {
      if (kIsWeb) {
        await launchUrl(webUri, mode: LaunchMode.platformDefault);
        return;
      }
      if (await canLaunchUrl(tgUri)) {
        await launchUrl(tgUri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(R.telegramNotInstalled)),
        );
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e, s) {
      debugPrint('openSupport error: $e\n$s');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(R.telegramOpenFailed)),
      );
    }
  }

  Future<void> _openAddContact(BuildContext context) async {
    if (!kIsWeb) HapticFeedback.selectionClick();
    final saved = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddContactScreen()),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(R.contactSaved)),
      );
    }
  }

  /// Определяем количество колонок для адаптива
  int _calcColumns(BoxConstraints c) {
    final w = c.maxWidth;
    if (w >= 1200) return 3;
    if (w >= 800) return 2;
    return 1;
  }

  double _gridChildAspectRatio(
    BoxConstraints constraints,
    int cols,
    EdgeInsets listPadding,
  ) {
    final horizontalPadding = listPadding.left + listPadding.right;
    const spacing = 12.0;
    final totalSpacing = horizontalPadding + spacing * (cols - 1);
    final availableWidth = constraints.maxWidth - totalSpacing;
    final cellWidth = availableWidth <= 0 ? 1.0 : availableWidth / cols;
    final viewportHeight = constraints.maxHeight;
    final baseHeight = cellWidth / 1.9; // предпочитаем умеренно широкие карточки
    const minHeight = 140.0;
    final fallbackMaxHeight = cellWidth * 1.1;
    final maxHeight = viewportHeight.isFinite
        ? math.max(minHeight, viewportHeight * 0.6)
        : fallbackMaxHeight;
    final cellHeight = baseHeight.clamp(minHeight, maxHeight).toDouble();
    return cellWidth / cellHeight;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text(R.appTitle)),
      drawer: NavigationDrawer(
        selectedIndex: 0, // индекс выбранного пункта
        onDestinationSelected: (index) {
          Navigator.pop(context);
          switch (index) {
            case 1:
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              break;
            case 2:
              _openSupport(context);
              break;
            default:
              break;
          }
        },
        children: const [
          NavigationDrawerDestination(
            icon: Icon(Icons.home),
            selectedIcon: Icon(Icons.home_filled),
            label: Text(R.homeTitle),
          ),
          NavigationDrawerDestination(
            icon: Icon(Icons.settings),
            selectedIcon: Icon(Icons.settings_suggest),
            label: Text(R.settings),
          ),
          NavigationDrawerDestination(
            icon: Icon(Icons.support_agent),
            selectedIcon: Icon(Icons.support),
            label: Text(R.support),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<Counts>(
            future: _countsFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint('Error loading contact counts: ${snapshot.error}\n${snapshot.stackTrace}');
                _showLoadErrorOnce(context);
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: _listPadding(context),
                  children: const [
                    _ErrorCard(),
                    kGap12,
                    _CategoryCard.loading(category: ContactCategory.partner),
                    kGap12,
                    _CategoryCard.loading(category: ContactCategory.client),
                    kGap12,
                    _CategoryCard.loading(category: ContactCategory.prospect),
                  ],
                );
              }
              _loadErrorShown = false;

              final isLoading = snapshot.connectionState == ConnectionState.waiting;
              final counts = snapshot.data ?? Counts({
                for (final c in ContactCategory.values) c: 0,
              });

              // Пустое состояние
              if (!isLoading && counts.allZero) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: _listPadding(context),
                  children: [
                    Card(
                      child: Padding(
                        padding: kPad16,
                        child: Column(
                          children: [
                            const Icon(Icons.person_off, size: 40),
                            kGap8,
                            const Text(R.noContacts),
                            kGap8,
                            FilledButton.icon(
                              onPressed: () => _openAddContact(context),
                              icon: const Icon(Icons.person_add),
                              label: const Text(R.addContact),
                            ),
                          ],
                        ),
                      ),
                    ),
                    kGap12,
                    // Показываем категории с "Нет данных"
                    ...ContactCategory.values.map(
                          (cat) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CategoryCard(
                          category: cat,
                          subtitle: R.noData,
                          trailingCount: null,
                          isLoading: false,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ContactListScreen(category: cat.dbKey, title: cat.titlePlural),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              }

              // Основной список/сетка
              final showSummary = !isLoading && !counts.allZero;
              final listPadding = _listPadding(context);

              return LayoutBuilder(
                builder: (context, constraints) {
                  final cols = _calcColumns(constraints);

                  List<Widget> buildItems({required bool skeleton}) {
                    return ContactCategory.values.map((cat) {
                      if (skeleton) return _CategoryCard.loading(category: cat);
                      final c = counts.of(cat);
                      final subtitle = (c < 0)
                          ? R.unknown
                          : cat.russianCount(c); // -1 → неизвестно, иначе склонение
                      final chip = (c < 0) ? '—' : '$c';
                      return _CategoryCard(
                        category: cat,
                        subtitle: isLoading ? R.loading : subtitle,
                        trailingCount: isLoading ? null : chip,
                        isLoading: isLoading,
                        onTap: () {
                          if (!kIsWeb) HapticFeedback.selectionClick();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ContactListScreen(category: cat.dbKey, title: cat.titlePlural),
                            ),
                          );
                        },
                      );
                    }).toList();
                  }

                  final items = buildItems(skeleton: isLoading);

                  if (cols == 1) {
                    return Scrollbar(
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: listPadding,
                        itemCount: items.length + (showSummary ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          if (showSummary && i == 0) {
                            return _SummaryCard(
                              knownTotal: counts.knownTotal,
                              unknownCount: counts.unknownCount,
                              onAddContact: () => _openAddContact(context),
                              onOpenSettings: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                                );
                              },
                              onOpenSupport: () => _openSupport(context),
                            );
                          }
                          final index = showSummary ? i - 1 : i;
                          return items[index];
                        },
                      ),
                    );
                  }

                  // 2–3 колонки (планшет/desktop/web)
                  return Scrollbar(
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        if (showSummary)
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              listPadding.left,
                              listPadding.top,
                              listPadding.right,
                              12,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: _SummaryCard(
                                knownTotal: counts.knownTotal,
                                unknownCount: counts.unknownCount,
                                onAddContact: () => _openAddContact(context),
                                onOpenSettings: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const SettingsScreen()),
                                  );
                                },
                                onOpenSupport: () => _openSupport(context),
                              ),
                            ),
                          ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            listPadding.left,
                            showSummary ? 0 : listPadding.top,
                            listPadding.right,
                            listPadding.bottom,
                          ),
                          sliver: SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => items[i],
                              childCount: items.length,
                            ),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cols,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: _gridChildAspectRatio(
                                constraints,
                                cols,
                                listPadding,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: R.addContact,
        onPressed: () => _openAddContact(context),
        label: const Text(R.addContact),
        icon: const Icon(Icons.person_add),
      ),
    );
  }
}

/// ---------------------
/// Виджеты
/// ---------------------

class _SummaryCard extends StatelessWidget {
  final int knownTotal;
  final int unknownCount;
  final VoidCallback onAddContact;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenSupport;

  const _SummaryCard({
    required this.knownTotal,
    required this.unknownCount,
    required this.onAddContact,
    required this.onOpenSettings,
    required this.onOpenSupport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final hasUnknown = unknownCount > 0;

    return Card(
      child: Padding(
        padding: kPad16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(R.summaryTitle, style: textTheme.titleMedium),
            kGap8,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        R.summaryKnownLabel,
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        knownTotal.toString(),
                        style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                if (hasUnknown)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 4),
                    child: Icon(Icons.info_outline, color: colorScheme.secondary),
                  ),
              ],
            ),
            kGap8,
            Text(
              hasUnknown ? R.summaryUnknown(unknownCount) : R.summaryAllKnown,
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            kGap12,
            Text(
              R.quickActions,
              style: textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            kGap8,
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onAddContact,
                  icon: const Icon(Icons.person_add),
                  label: const Text(R.addContact),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings),
                  label: const Text(R.settings),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenSupport,
                  icon: const Icon(Icons.support_agent),
                  label: const Text(R.support),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatefulWidget {
  const _ErrorCard({super.key});

  @override
  State<_ErrorCard> createState() => _ErrorCardState();
}

class _ErrorCardState extends State<_ErrorCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: kPad16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(R.loadError, style: TextStyle(fontWeight: FontWeight.w600)),
            kGap8,
            const Text(R.checkNetwork),
            kGap8,
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                setState(() => _busy = true);
                // Найдём ближайший RefreshIndicator и дёрнем refresh
                final state = context.findAncestorStateOfType<_HomeScreenState>();
                await state?._refresh();
                if (mounted) setState(() => _busy = false);
              },
              icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              label: Text(_busy ? R.loading : R.tryAgain),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatefulWidget {
  final ContactCategory category;
  final String subtitle;
  final String? trailingCount; // null — без чипа (скелетон/загрузка)
  final VoidCallback onTap;
  final bool isLoading;

  const _CategoryCard({
    super.key,
    required this.category,
    required this.subtitle,
    required this.onTap,
    required this.trailingCount,
    this.isLoading = false,
  });

  const _CategoryCard.loading({super.key, required ContactCategory category})
      : category = category,
        subtitle = R.loading,
        trailingCount = null,
        onTap = _noop,
        isLoading = true;

  static void _noop() {}
  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.isLoading) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLoading = widget.isLoading;

    Widget leadingIcon = Icon(widget.category.icon, size: 32, color: colorScheme.primary);

    if (!isLoading) {
      leadingIcon = Hero(
        tag: 'cat:${widget.category.dbKey}',
        transitionOnUserGestures: true,
        flightShuttleBuilder: (ctx, anim, dir, fromCtx, toCtx) {
          return ScaleTransition(
            scale: anim.drive(Tween(begin: 0.9, end: 1.0).chain(CurveTween(curve: Curves.easeOut))),
            child: Icon(widget.category.icon, size: 32, color: colorScheme.primary),
          );
        },
        child: leadingIcon,
      );
    }

      final Widget trailingContent = widget.trailingCount == null
          ? const Icon(Icons.chevron_right)
          : Row(
              key: ValueKey(widget.trailingCount), // ключ для AnimatedSwitcher
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: '${R.qtyLabel}: ${widget.trailingCount}',
                  child: Semantics(
                    label: '${widget.category.titlePlural}: ${R.qtyLabel.toLowerCase()}',
                    value: widget.trailingCount,
                    child: Chip(
                      label: Text(
                        widget.trailingCount!,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      backgroundColor: colorScheme.primaryContainer,
                      side: BorderSide(color: colorScheme.outlineVariant),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            );

    return Semantics(
      button: true,
      label: widget.category.titlePlural,
      value: widget.subtitle,
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1.0,
        duration: kDurTap,
        child: Material(
          color: colorScheme.surfaceVariant,
          elevation: 1.5,
          borderRadius: kBr16,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: kBr16,
            onTap: isLoading
                ? null
                : () {
              if (!kIsWeb) HapticFeedback.selectionClick();
              widget.onTap();
            },
            onTapDown: (_) => _setPressed(true),
            onTapCancel: () => _setPressed(false),
            onTapUp: (_) => _setPressed(false),
            child: Padding(
              padding: kPad16,
              child: Row(
                children: [
                  leadingIcon,
                  kGap16w,
                  Expanded(
                    child: _TitleAndSubtitle(
                      title: widget.category.titlePlural,
                      subtitle: widget.subtitle,
                      isLoading: isLoading,
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: kDurFast,
                    transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                    child: trailingContent,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Заголовок/подзаголовок с простым скелетоном (без пакетов)
class _TitleAndSubtitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isLoading;

  const _TitleAndSubtitle({
    required this.title,
    required this.subtitle,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SkeletonLine(widthFactor: 0.5),
          kGap6,
          _SkeletonLine(widthFactor: 0.35),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: kDurFast,
          transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
          child: Text(
            subtitle,
            key: ValueKey(subtitle),
            style: textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double widthFactor;
  const _SkeletonLine({required this.widthFactor});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 16,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
