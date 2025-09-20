import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'add_contact_screen.dart';
import 'settings_screen.dart';
import 'contact_list_screen.dart';
import '../services/contact_database.dart';

/// ---------------------
/// Константы оформления
/// ---------------------
const kPad16 = EdgeInsets.all(16);
const kPadList = EdgeInsets.fromLTRB(16, 16, 16, 120);
const kGap8 = SizedBox(height: 8);
const kGap12 = SizedBox(height: 12);
const kGap16w = SizedBox(width: 16);
const kDurTap = Duration(milliseconds: 90);
const kDurFast = Duration(milliseconds: 200);
const kBr16 = BorderRadius.all(Radius.circular(16));

/// ---------------------
/// Типобезопасные категории
/// ---------------------
enum ContactCategory { partner, client, prospect }

extension ContactCategoryX on ContactCategory {
  /// Ключ в БД
  String get dbKey => switch (this) {
    ContactCategory.partner => 'Партнёр',
    ContactCategory.client => 'Клиент',
    ContactCategory.prospect => 'Потенциальный',
  };

  /// Заголовок карточки (мн. число)
  String get titlePlural => switch (this) {
    ContactCategory.partner => 'Партнёры',
    ContactCategory.client => 'Клиенты',
    ContactCategory.prospect => 'Потенциальные клиенты',
  };

  /// Иконка категории
  IconData get icon => switch (this) {
    ContactCategory.partner => Icons.handshake,
    ContactCategory.client => Icons.people,
    ContactCategory.prospect => Icons.person_add_alt_1,
  };

  /// Текст склонений для русской локали
  /// zero/one/few/many — формы существительных.
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
      return '$count $word';
    }

    return switch (this) {
      ContactCategory.partner => pick(one: 'партнёр', few: 'партнёра', many: 'партнёров'),
      ContactCategory.client => pick(one: 'клиент', few: 'клиента', many: 'клиентов'),
      ContactCategory.prospect =>
          pick(one: 'потенциальный клиент', few: 'потенциальных клиента', many: 'потенциальных клиентов'),
    };
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<int>> _countsFuture;
  late final VoidCallback _revListener;
  bool _loadErrorShown = false;

  @override
  void initState() {
    super.initState();
    _countsFuture = _loadCounts();
    // Единый источник обновлений: слушаем ревизию и перезагружаем future.
    _revListener = _refresh;
    ContactDatabase.instance.revision.addListener(_revListener);
  }

  @override
  void dispose() {
    ContactDatabase.instance.revision.removeListener(_revListener);
    super.dispose();
  }

  // Безопасный обёртчик: возвращаем -1 при ошибке вместо падения Future.wait
  Future<int> _safe(Future<int> f) async {
    try {
      return await f;
    } catch (e, s) {
      debugPrint('count error: $e\n$s');
      return -1; // -1 = неизвестно
    }
  }

  Future<List<int>> _loadCounts() async {
    // Порядок соответствует ContactCategory.values
    return Future.wait<int>([
      _safe(ContactDatabase.instance.countByCategory(ContactCategory.partner.dbKey)),
      _safe(ContactDatabase.instance.countByCategory(ContactCategory.client.dbKey)),
      _safe(ContactDatabase.instance.countByCategory(ContactCategory.prospect.dbKey)),
    ]);
  }

  Future<void> _refresh() async {
    setState(() {
      _countsFuture = _loadCounts();
    });
  }

  void _showLoadErrorOnce(BuildContext context) {
    if (_loadErrorShown) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить данные')),
      );
    });
    _loadErrorShown = true;
  }

  Future<void> _openSupport(BuildContext context) async {
    const group = 'touchnotebook';
    final tgUri = Uri.parse('tg://resolve?domain=$group');
    final webUri = Uri.parse('https://t.me/$group');
    try {
      // На Web лучше сразу открыть браузер
      if (kIsWeb) {
        await launchUrl(webUri, mode: LaunchMode.platformDefault);
        return;
      }
      if (await canLaunchUrl(tgUri)) {
        await launchUrl(tgUri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Telegram не установлен, откроем в браузере')),
        );
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть Telegram')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Touch NoteBook'),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(color: colorScheme.primary),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: colorScheme.onPrimary,
                      child: Icon(Icons.menu_book, size: 36, color: colorScheme.primary),
                    ),
                    kGap16w,
                    Text('Touch NoteBook', style: TextStyle(fontSize: 20, color: colorScheme.onPrimary)),
                  ],
                ),
              ),
              // Текущий экран — отмечаем selected для доступности
              const ListTile(
                leading: Icon(Icons.home),
                title: Text('Главный экран'),
                selected: true,
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Настройки'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.support_agent),
                title: const Text('Поддержка'),
                onTap: () {
                  Navigator.pop(context);
                  _openSupport(context);
                },
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<int>>(
            future: _countsFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint('Error loading contact counts: ${snapshot.error}\n${snapshot.stackTrace}');
                _showLoadErrorOnce(context);
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: kPadList,
                  children: [
                    _ErrorCard(onRetry: _refresh),
                    kGap12,
                    ...ContactCategory.values.map((cat) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CategoryCard.loading(category: cat),
                    )),
                  ],
                );
              }
              _loadErrorShown = false;

              final isLoading = snapshot.connectionState == ConnectionState.waiting;
              final counts = snapshot.data ?? const [0, 0, 0];

              // Пустое состояние: нет ни одного контакта
              if (!isLoading && counts.every((e) => e == 0)) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: kPadList,
                  children: [
                    Card(
                      child: Padding(
                        padding: kPad16,
                        child: Column(
                          children: [
                            const Icon(Icons.person_off, size: 40),
                            kGap8,
                            const Text('Пока нет контактов'),
                            kGap8,
                            FilledButton.icon(
                              onPressed: () async {
                                final saved = await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const AddContactScreen()),
                                );
                                if (saved == true && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Контакт сохранён')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.person_add),
                              label: const Text('Добавить контакт'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    kGap12,
                    // Категории с меткой "Нет данных"
                    ...ContactCategory.values.map((cat) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CategoryCard(
                        category: cat,
                        subtitle: 'Нет данных',
                        trailingCount: null,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ContactListScreen(
                                category: cat.dbKey,
                                title: cat.titlePlural,
                              ),
                            ),
                          );
                        },
                      ),
                    )),
                  ],
                );
              }

              // Основной список
              return Scrollbar(
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: kPadList,
                  itemCount: ContactCategory.values.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final cat = ContactCategory.values[index];
                    final c = isLoading ? null : counts[index];

                    String subtitle;
                    String? chipText;

                    if (c == null) {
                      subtitle = 'Загрузка…';
                      chipText = null;
                    } else if (c < 0) {
                      subtitle = 'Неизвестно';
                      chipText = '—';
                    } else {
                      subtitle = cat.russianCount(c);
                      chipText = '$c';
                    }

                    return isLoading
                        ? _CategoryCard.loading(category: cat)
                        : _CategoryCard(
                      category: cat,
                      subtitle: subtitle,
                      trailingCount: chipText,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ContactListScreen(
                              category: cat.dbKey,
                              title: cat.titlePlural,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'Добавить контакт',
        onPressed: () async {
          final saved = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddContactScreen()),
          );
          if (saved == true && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Контакт сохранён')),
            );
          }
        },
        label: const Text('Добавить контакт'),
        icon: const Icon(Icons.person_add),
      ),
    );
  }
}

/// ---------------------
/// Виджеты
/// ---------------------

class _ErrorCard extends StatelessWidget {
  final Future<void> Function() onRetry;
  const _ErrorCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: kPad16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ошибка загрузки данных', style: TextStyle(fontWeight: FontWeight.w600)),
            kGap8,
            const Text('Проверьте подключение к сети и попробуйте ещё раз.'),
            kGap8,
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
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
  final String? trailingCount; // текст в чипе справа; null — без чипа
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.subtitle,
    required this.onTap,
    required this.trailingCount,
  });

  /// Скелетон-заглушка на время загрузки
  factory _CategoryCard.loading({required ContactCategory category}) {
    return _CategoryCard(
      category: category,
      subtitle: 'Загрузка…',
      trailingCount: null,
      onTap: () {},
    );
  }

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    setState(() {
      _pressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLoading = widget.onTap == () {}; // примитивная проверка для скелетона

    Widget leadingIcon = Icon(widget.category.icon, size: 32, color: colorScheme.primary);

    // Hero для не-скелетона
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

    final trailing = widget.trailingCount == null
        ? const Icon(Icons.chevron_right)
        : Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Чип с количеством
        Semantics(
          label: 'Количество',
          value: widget.trailingCount,
          child: Chip(
            label: Text(widget.trailingCount!, style: const TextStyle(fontWeight: FontWeight.w600)),
            backgroundColor: colorScheme.primaryContainer,
            side: BorderSide(color: colorScheme.outlineVariant),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
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
            onTap: isLoading ? null : widget.onTap,
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
                  trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Отдельный виджет заголовка/подзаголовка с простым скелетоном без пакетов
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
          SizedBox(height: 6),
          _SkeletonLine(widthFactor: 0.35),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textTheme.titleMedium),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: kDurFast,
          transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
          child: Text(subtitle, key: ValueKey(subtitle), style: textTheme.bodyMedium),
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
