import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import 'add_contact_screen.dart';
import 'settings_screen.dart';
import 'contact_list_screen.dart';
import '../services/contact_database.dart';
import '../services/push_notifications.dart';


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
  static const linkCopied = 'Ссылка скопирована';
  static const emptyStateHelp =
      'Создайте первый контакт. Ниже можно открыть списки по категориям.';
  static const chipHintOpenList = 'Откройте список по категории';
  static const dataUpdated = 'Данные обновлены';
  static const showNotification = 'Показать уведомление';
  static const notificationMessage = 'Это тестовое push-уведомление.';
  static const notificationPickDate = 'Выберите дату уведомления';
  static const notificationPickTime = 'Выберите время уведомления';
  static const notificationDateInPast =
      'Выбранная дата и время уже прошли. Выберите другой момент.';

  static String notificationScheduledAt(String formattedDate) {
    return 'Уведомление запланировано на $formattedDate';
  }

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
const kDurTap = Duration(milliseconds: 120);
const kDurFast = Duration(milliseconds: 200);
const kBr16 = BorderRadius.all(Radius.circular(16));

EdgeInsets _listPadding(BuildContext context) {
  // SafeArea уже обрабатывает системные отступы снизу.
  const fabEstimatedHeight = 56.0; // высота FAB.extended
  const bottom = 16 + kFloatingActionButtonMargin + fabEstimatedHeight;
  return const EdgeInsets.fromLTRB(16, 16, 16, bottom);
}

/// Кешированный форматтер чисел для RU
final NumberFormat _nfRu = NumberFormat.decimalPattern('ru');

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
      return '${_nfRu.format(count)}\u00A0$word';
    }

    return switch (this) {
      ContactCategory.partner =>
          pick(one: 'партнёр', few: 'партнёра', many: 'партнёров'),
      ContactCategory.client =>
          pick(one: 'клиент', few: 'клиента', many: 'клиентов'),
      ContactCategory.prospect => pick(
        one: 'потенциальный клиент',
        few: 'потенциальных клиента',
        many: 'потенциальных клиентов',
      ),
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

  int get unknownCount => ContactCategory.values.where((c) => of(c) < 0).length;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Counts) return false;
    for (final c in ContactCategory.values) {
      if (of(c) != other.of(c)) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(ContactCategory.values.map(of));
}

/// ---------------------
/// Экран
/// ---------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RestorationMixin {
  late Future<Counts> _countsFuture;
  late final VoidCallback _revListener;
  bool _loadErrorShown = false;

  // debounce для частых ревизий
  Timer? _debounce;

  // Для уведомления «Данные обновлены»
  Counts? _lastCountsShown;

  // Последние валидные данные для устойчивого UI во время refresh
  Counts? _lastGoodCounts;

  // Restoration
  final RestorableInt _drawerIndex = RestorableInt(0);

  @override
  String? get restorationId => 'home_screen';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_drawerIndex, 'home_drawer_index');
  }

  @override
  void initState() {
    super.initState();
    _countsFuture = _loadCounts();
    _revListener = _scheduleRefresh;
    ContactDatabase.instance.revision.addListener(_revListener);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    ContactDatabase.instance.revision.removeListener(_revListener);
    _drawerIndex.dispose();
    super.dispose();
  }

  Future<int> _safe(Future<int> f) async {
    try {
      // если источник «подвис», через 3 сек показываем «Неизвестно»
      return await f.timeout(const Duration(seconds: 3));
    } catch (e, s) {
      debugPrint('count error: $e\n$s');
      return -1; // -1 = неизвестно
    }
  }

  Future<Counts> _loadCounts() async {
    final partner = await _safe(
        ContactDatabase.instance.countByCategory(ContactCategory.partner.dbKey));
    final client = await _safe(
        ContactDatabase.instance.countByCategory(ContactCategory.client.dbKey));
    final prospect = await _safe(
        ContactDatabase.instance.countByCategory(ContactCategory.prospect.dbKey));
    return Counts({
      ContactCategory.partner: partner,
      ContactCategory.client: client,
      ContactCategory.prospect: prospect,
    });
  }

  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() {
        _countsFuture = _loadCounts();
      });
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
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e, s) {
      debugPrint('openSupport error: $e\n$s');
      if (!mounted) return;
      // мягкий fallback — скопируем ссылку
      await Clipboard.setData(
        const ClipboardData(text: 'https://t.me/touchnotebook'),
      );
      if (!mounted) return;
    }
  }

  Future<void> _openAddContact(BuildContext context) async {
    if (!kIsWeb) HapticFeedback.selectionClick();
    final saved = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddContactScreen()),
    );
    if (saved == true && mounted) {
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
    final baseHeight = cellWidth / 1.9; // умеренно широкие карточки
    const minHeight = 140.0;
    final fallbackMaxHeight = cellWidth * 1.1;
    final maxHeight = viewportHeight.isFinite
        ? math.max(minHeight, viewportHeight * 0.6)
        : fallbackMaxHeight;
    final cellHeight = baseHeight.clamp(minHeight, maxHeight).toDouble();
    return cellWidth / cellHeight;
  }

  void _maybeNotifyUpdated(Counts newCounts) {
    final last = _lastCountsShown;
    if (last == null) {
      _lastCountsShown = newCounts;
      // кэшируем «хорошие» данные
      if (newCounts.unknownCount == 0 || newCounts.knownTotal > 0) {
        _lastGoodCounts = newCounts;
      }
      return;
    }

    _lastCountsShown = newCounts;

    // обновим кэш «хороших» данных
    if (newCounts.unknownCount == 0 || newCounts.knownTotal > 0) {
      _lastGoodCounts = newCounts;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      restorationId: 'home_scaffold',
      appBar: AppBar(
        title: const Text(R.homeTitle),
        actions: [
          IconButton(
            tooltip: R.showNotification,
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: _showDemoNotification,
          ),
        ],
      ),
      drawer: NavigationDrawer(
        selectedIndex: _drawerIndex.value,
        onDestinationSelected: (index) {
          _drawerIndex.value = index;
          Navigator.pop(context);
          switch (index) {
            case 1:
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
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
              final waiting = snapshot.connectionState == ConnectionState.waiting;
              final hasSomeData = snapshot.hasData || _lastGoodCounts != null;

              // если есть хоть какие-то прошлые данные — используем их
              final counts = snapshot.data ??
                  _lastGoodCounts ??
                  Counts({ for (final c in ContactCategory.values) c: 0 });

              // если пришла ошибка и данных нет вообще — показываем карточку ошибки
              if (snapshot.hasError && !hasSomeData) {
                debugPrint(
                  'Error loading contact counts: ${snapshot.error}\n${snapshot.stackTrace}',
                );
                _showLoadErrorOnce(context);
                return ListView(
                  key: const PageStorageKey('home-error-list'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: _listPadding(context),
                  children: const [ _ErrorCard(onRetry: null) ],
                );
              }

              _loadErrorShown = false;

              // уведомим об обновлении (после кадра)
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && snapshot.hasData) _maybeNotifyUpdated(snapshot.data!);
              });

              final isInitialLoad = !hasSomeData && waiting;

              // Первичная загрузка — скромный placeholder
              if (isInitialLoad) {
                return ListView(
                  key: const PageStorageKey('home-initial-loading'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: _listPadding(context),
                  children: const [
                    _SkeletonLine(widthFactor: 0.9),
                    SizedBox(height: 12),
                    _SkeletonLine(widthFactor: 0.85),
                    SizedBox(height: 12),
                    _SkeletonLine(widthFactor: 0.8),
                  ],
                );
              }

              // Основной список/сетка
              final showSummary = !counts.allZero; // сводка остаётся при refresh
              final listPadding = _listPadding(context);

              return LayoutBuilder(
                builder: (context, constraints) {
                  final cols = _calcColumns(constraints);

                  final items = ContactCategory.values.map((cat) {
                    final c = counts.of(cat);
                    final subtitle = (c < 0) ? R.unknown : cat.russianCount(c);
                    final chip = (c < 0) ? '—' : _nfRu.format(c);
                    return _CategoryCard(
                      category: cat,
                      subtitle: subtitle,
                      trailingCount: chip,
                      isLoading: false, // НЕ скрываем карточки при refresh
                      onTap: () {
                        if (!kIsWeb) HapticFeedback.selectionClick();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ContactListScreen(
                              category: cat.dbKey,
                              title: cat.titlePlural,
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(growable: false);

                  if (cols == 1) {
                    return Scrollbar(
                      child: ListView.separated(
                        key: const PageStorageKey('home-list'),
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
                                  MaterialPageRoute(
                                    builder: (_) => const SettingsScreen(),
                                  ),
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
                    thumbVisibility: true,
                    child: CustomScrollView(
                      key: const PageStorageKey('home-grid'),
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
                                      builder: (_) => const SettingsScreen(),
                                    ),
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
                              (_, i) => RepaintBoundary(child: items[i]),
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

  Future<void> _showDemoNotification() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDate = today.add(const Duration(days: 365));

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: lastDate,
      helpText: R.notificationPickDate,
    );

    if (!mounted || selectedDate == null) {
      return;
    }

    final nextMinute = now.add(const Duration(minutes: 1));
    final initialTime = TimeOfDay(hour: nextMinute.hour, minute: nextMinute.minute);

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: R.notificationPickTime,
    );

    if (!mounted || selectedTime == null) {
      return;
    }

    final scheduledDate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    if (!scheduledDate.isAfter(DateTime.now())) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(R.notificationDateInPast)),
      );
      return;
    }

    await PushNotifications.scheduleNotification(
      id: 1001,
      title: R.appTitle,
      body: R.notificationMessage,
      scheduledDate: scheduledDate,
    );

    if (!mounted) return;

    final formatted =
        DateFormat('d MMMM yyyy, HH:mm', 'ru').format(scheduledDate);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(R.notificationScheduledAt(formatted))),
    );
  }
}

/// ---------------------
/// Виджеты
/// ---------------------

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: kPad16,
        child: Column(
          children: [
            Icon(Icons.person_off, size: 40),
            kGap8,
            Text(R.noContacts),
            kGap8,
            Text(
              R.emptyStateHelp,
              textAlign: TextAlign.center,
            ),
            kGap8,
            _AddContactButton(),
          ],
        ),
      ),
    );
  }
}

class _AddContactButton extends StatelessWidget {
  const _AddContactButton();

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () {
        final state = context.findAncestorStateOfType<_HomeScreenState>();
        state?._openAddContact(context);
      },
      icon: const Icon(Icons.person_add),
      label: const Text(R.addContact),
    );
  }
}

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
                        _nfRu.format(knownTotal),
                        style: textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                if (hasUnknown)
                  Semantics(
                    label: 'Есть неизвестные категории',
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12, top: 4),
                      child: Icon(Icons.info_outline,
                          color: colorScheme.secondary),
                    ),
                  ),
              ],
            ),
            kGap8,
            Text(
              hasUnknown ? R.summaryUnknown(unknownCount) : R.summaryAllKnown,
              style: textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatefulWidget {
  final Future<void> Function()? onRetry;
  const _ErrorCard({super.key, required this.onRetry});

  @override
  State<_ErrorCard> createState() => _ErrorCardState();
}

class _ErrorCardState extends State<_ErrorCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final onRetry = widget.onRetry;
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
              onPressed: _busy || onRetry == null
                  ? null
                  : () async {
                setState(() => _busy = true);
                await onRetry();
                if (mounted) setState(() => _busy = false);
              },
              icon: _busy
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
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
    if (widget.isLoading || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLoading = widget.isLoading;

    Widget leadingIcon =
    Icon(widget.category.icon, size: 32, color: colorScheme.primary);

    if (!isLoading) {
      leadingIcon = Hero(
        tag: 'cat:${widget.category.dbKey}',
        transitionOnUserGestures: true,
        flightShuttleBuilder: (ctx, anim, dir, fromCtx, toCtx) {
          return ScaleTransition(
            scale: anim
                .drive(Tween(begin: 0.9, end: 1.0).chain(CurveTween(curve: Curves.easeOut))),
            child:
            Icon(widget.category.icon, size: 32, color: colorScheme.primary),
          );
        },
        child: leadingIcon,
      );
    }

    final String? countStr = widget.trailingCount;
    final bool isUnknown = countStr == '—';

    final Widget trailingContent = countStr == null
        ? const Icon(Icons.chevron_right)
        : Row(
      key: ValueKey(countStr), // ключ для AnimatedSwitcher
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: isUnknown
              ? 'Количество неизвестно — данные обновятся автоматически'
              : '${R.qtyLabel}: $countStr',
          child: Semantics(
            label:
            '${widget.category.titlePlural}: ${R.qtyLabel.toLowerCase()}',
            value: isUnknown ? R.unknown : countStr,
            hint: '${R.chipHintOpenList}: ${widget.category.titlePlural}',
            child: Chip(
              label: Text(
                countStr,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              backgroundColor: isUnknown
                  ? colorScheme.surfaceVariant
                  : colorScheme.primaryContainer,
              side: BorderSide(
                color: isUnknown
                    ? colorScheme.outline
                    : colorScheme.outlineVariant,
              ),
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
          color: theme.colorScheme.surfaceContainerHigh, // контрастнее, чем surfaceVariant
          elevation: 2,
          borderRadius: kBr16,
          clipBehavior: Clip.antiAlias,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: InkWell(
              focusColor: kIsWeb ? theme.focusColor : Colors.transparent,
              hoverColor: kIsWeb ? theme.hoverColor : Colors.transparent,
              borderRadius: kBr16,
              canRequestFocus: !isLoading,
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
                      transitionBuilder: (child, anim) =>
                          FadeTransition(opacity: anim, child: child),
                      child: trailingContent,
                    ),
                  ],
                ),
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
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonLine(widthFactor: 0.5),
          kGap6,
          _SkeletonLine(widthFactor: 0.35),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: kDurFast,
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
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
