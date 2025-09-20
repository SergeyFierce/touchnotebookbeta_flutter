import 'dart:async';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

import '../app.dart'; // для App.navigatorKey
import '../models/contact.dart';
import '../services/contact_database.dart';
import '../widgets/system_notifications.dart';
import 'add_contact_screen.dart';
import 'contact_details_screen.dart';
import 'package:characters/characters.dart';

// Утилитный класс для цветов статусов и тегов (остаёмся на статической палитре как в основе)
class ContactColors {
  static Color statusColor(String status) {
    switch (status) {
      case 'Активный':
        return Colors.green;
      case 'Пассивный':
        return Colors.orange;
      case 'Потерянный':
        return Colors.red;
      case 'Холодный':
        return Colors.cyan;
      case 'Тёплый':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  static Color tagColor(String tag) {
    switch (tag) {
      case 'Новый':
        return Colors.white;
      case 'Напомнить':
        return Colors.purple;
      case 'VIP':
        return Colors.yellow;
      default:
        return Colors.grey.shade200;
    }
  }

  static Color tagTextColor(String tag) {
    switch (tag) {
      case 'Новый':
        return Colors.black;
      case 'Напомнить':
        return Colors.white;
      case 'VIP':
        return Colors.black;
      default:
        return Colors.black;
    }
  }
}

class ContactListScreen extends StatefulWidget {
  final String category; // singular value for DB
  final String title; // display title
  final int? scrollToId; // к какому id проскроллить/подсветить при открытии
  const ContactListScreen({
    super.key,
    required this.category,
    required this.title,
    this.scrollToId,
  });

  static String _titleForCategory(String cat) {
    switch (cat) {
      case 'Партнёр':
        return 'Партнёры';
      case 'Клиент':
        return 'Клиенты';
      case 'Потенциальный':
        return 'Потенциальные';
      default:
        return cat;
    }
  }

  // === РЕЕСТР АКТИВНЫХ СПИСКОВ ПО КАТЕГОРИИ ===
  static final Map<String, _ContactListScreenState> _mountedByCategory = {};

  /// Переходит к восстановленному контакту:
  /// если экран нужной категории уже смонтирован — просто обновляет список и подсвечивает.
  /// иначе — делает одиночный push нового списка.
  static Future<void> goToRestored(Contact restored, int restoredId) async {
    final existing = _mountedByCategory[restored.category];
    if (existing != null && existing.mounted) {
      final restoredWithId = restored.copyWith(id: restoredId);
      existing._restoreLocally(restoredWithId, highlight: true);
      return;
    }
    final title = _titleForCategory(restored.category);
    App.navigatorKey.currentState?.push(
      MaterialPageRoute(
        settings: RouteSettings(name: 'ContactList:${restored.category}'),
        builder: (_) => ContactListScreen(
          category: restored.category,
          title: title,
          scrollToId: restoredId,
        ),
      ),
    );
  }

  @override
  State<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends State<ContactListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scroll = ScrollController();
  int _pulseSeed = 0; // триггер импульса для карточек
  // ключи карточек по id для ensureVisible
  final Map<int, GlobalKey> _itemKeys = {};

  // Константы для durations и резерва
  static const double fabReserve = 56 + 16; // Высота FAB + отступ
  static const Duration debounceDuration = Duration(milliseconds: 300);
  static const Duration highlightDuration = Duration(milliseconds: 1800);
  static const Duration undoDuration = Duration(seconds: 4);
  static const Duration pulseDuration = Duration(milliseconds: 3250);

  Timer? _debounce;
  OverlaySupportEntry? _undoBanner;
  Timer? _highlightTimer;

  void _restoreLocally(Contact restored, {bool highlight = false}) {
    // если вдруг уже есть с таким id — заменим, иначе добавим
    final i = _all.indexWhere((e) => e.id == restored.id);
    setState(() {
      if (i >= 0) {
        _all[i] = restored;
      } else {
        _all.add(restored);
      }
      _cleanupKeys();
    });
    // подчёркивание — без автоскролла
    if (highlight && restored.id != null) {
      _flashHighlight(restored.id!);
    }
  }

  // подсветка восстановленного контакта
  int? _highlightId;

  String _query = '';
  SortOption _sort = SortOption.dateDesc;
  Set<String> _statusFilters = {};
  List<Contact> _all = [];
  static const int _pageSize = 20;
  int _page = 0;
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    // регистрируем экран в реестре активных по категории
    ContactListScreen._mountedByCategory[widget.category] = this;
    _loadContacts(reset: true);
    _scroll.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant ContactListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category) {
      // пере-регистрируем под новой категорией
      final s = ContactListScreen._mountedByCategory[oldWidget.category];
      if (identical(s, this)) {
        ContactListScreen._mountedByCategory.remove(oldWidget.category);
      }
      ContactListScreen._mountedByCategory[widget.category] = this;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _undoBanner = null;
    _undoBanner?.dismiss();
    _highlightTimer?.cancel();
    _searchController.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    // снимаем регистрацию
    final s = ContactListScreen._mountedByCategory[widget.category];
    if (identical(s, this)) {
      ContactListScreen._mountedByCategory.remove(widget.category);
    }
    super.dispose();
  }

  GlobalKey _keyFor(Contact c) {
    final id = c.id;
    if (id == null) return GlobalKey();
    return _itemKeys[id] ??= GlobalKey(debugLabel: 'contact_$id');
  }

  void _cleanupKeys() {
    final ids = _all.map((e) => e.id).whereType<int>().toSet();
    _itemKeys.removeWhere((k, v) => !ids.contains(k));
  }

  Future<void> _maybeScrollTo(int id) async {
    await Future.delayed(Duration.zero); // дождаться построения
    final key = _itemKeys[id];
    final ctx = key?.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(
        ctx,
        alignment: 0.1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }

  void _flashHighlight(int id) {
    _highlightTimer?.cancel();
    setState(() {
      _highlightId = id;
      _pulseSeed++; // ← новый триггер для импульса (seed меняется, чтобы перезапускать анимацию)
    });
    _highlightTimer = Timer(highlightDuration, () {
      if (mounted && _highlightId == id) {
        setState(() => _highlightId = null);
      }
    });
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadMoreContacts();
    }
  }

  Future<void> _loadContacts({bool reset = false}) async {
    if (reset) {
      _all.clear();
      _page = 0;
      _hasMore = true;
      _cleanupKeys();
    }
    await _loadMoreContacts();
  }

  Future<void> _loadMoreContacts() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);
    try {
      final contacts = await ContactDatabase.instance.contactsByCategoryPaged(
        widget.category,
        limit: _pageSize,
        offset: _page * _pageSize,
      );
      if (!mounted) return;
      setState(() {
        // защита от дублей при наложении страниц
        final existing = _all.map((e) => e.id).toSet();
        _all.addAll(contacts.where((e) => !existing.contains(e.id)));
        _isLoading = false;
        _page++;
        _hasMore = contacts.length >= _pageSize;
        _cleanupKeys();
      });
      if (widget.scrollToId != null && _all.any((e) => e.id == widget.scrollToId)) {
        final id = widget.scrollToId!;
        await _maybeScrollTo(id);
        _flashHighlight(id);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showErrorBanner('Ошибка загрузки контактов: $e');
      }
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(debounceDuration, () {
      if (!mounted) return;
      setState(() {
        _query = value.trim().toLowerCase();
      });
    });
  }

  void _openSort() async {
    final result = await showModalBottomSheet<SortOption>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<SortOption>(
                title: const Text('ФИО A→Я'),
                value: SortOption.nameAsc,
                groupValue: _sort,
                onChanged: (v) => Navigator.pop(context, v),
              ),
              RadioListTile<SortOption>(
                title: const Text('ФИО Я→A'),
                value: SortOption.nameDesc,
                groupValue: _sort,
                onChanged: (v) => Navigator.pop(context, v),
              ),
              RadioListTile<SortOption>(
                title: const Text('Новые сверху'),
                value: SortOption.dateDesc,
                groupValue: _sort,
                onChanged: (v) => Navigator.pop(context, v),
              ),
              RadioListTile<SortOption>(
                title: const Text('Старые сверху'),
                value: SortOption.dateAsc,
                groupValue: _sort,
                onChanged: (v) => Navigator.pop(context, v),
              ),
            ],
          ),
        );
      },
    );
    if (result != null) {
      setState(() => _sort = result);
    }
  }

  void _openFilters() async {
    // статусы зависят от категории
    final category = widget.category;
    final List<String> statuses = (category == 'Потенциальный')
        ? const ['Холодный', 'Тёплый', 'Потерянный']
        : const ['Активный', 'Пассивный', 'Потерянный'];
    final selected = Set<String>.from(_statusFilters);
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setStateSB) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context, <String>{}); // сброс
                            },
                            child: const Text('Сбросить'),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context, selected); // применить
                            },
                            child: const Text('Применить'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final s in statuses)
                              CheckboxListTile(
                                title: Text(s),
                                value: selected.contains(s),
                                onChanged: (v) {
                                  setStateSB(() {
                                    if (v == true) {
                                      selected.add(s);
                                    } else {
                                      selected.remove(s);
                                    }
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
    if (result != null) {
      setState(() => _statusFilters = result);
    }
  }

  Future<void> _showContactMenu(Contact c) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Детали контакта'),
                onTap: () => Navigator.pop(context, 'details'),
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Удалить'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        );
      },
    );
    if (action == 'details') {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ContactDetailsScreen(contact: c)),
      );
      // ⬇️ адресное обновление вместо _loadContacts(reset: true)
      if (!mounted) return;
      if (result is Contact) {
        setState(() {
          final i = _all.indexWhere((e) => e.id == result.id);
          if (i >= 0) _all[i] = result;
          _cleanupKeys();
        });
      } else if (result is Map && result['deletedId'] is int) {
        setState(() {
          _all.removeWhere((e) => e.id == result['deletedId']);
          _cleanupKeys();
        });
      }
    } else if (action == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Удалить контакт?'),
          content: const Text('Это действие нельзя отменить.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await _deleteWithUndo(c);
      }
    }
  }

  /// Удаляет контакт и показывает баннер с Undo + индикатором и обратным отсчётом.
  Future<void> _deleteWithUndo(Contact c) async {
    if (c.id == null) return;
    final db = ContactDatabase.instance;
    try {
      // 1) Снимок заметок + удаление контакта (каскад снесёт заметки)
      final notesSnapshot = await db.deleteContactWithSnapshot(c.id!);
      // 2) Убираем из локального списка
      setState(() {
        _all.removeWhere((e) => e.id == c.id);
        _cleanupKeys();
      });
      // 3) Баннера с возможностью отмены
      _undoBanner?.dismiss();
      _undoBanner = showUndoBanner(
        message: 'Контакт удалён',
        duration: undoDuration,
        icon: Icons.delete_outline,
        onUndo: () async {
          _undoBanner = null;
          final newId =
              await db.restoreContactWithNotes(c.copyWith(id: null), notesSnapshot);
          _restoreLocally(c.copyWith(id: newId), highlight: true);
        },
      );
    } catch (e) {
      if (mounted) {
        showErrorBanner('Ошибка удаления: $e');
        // Восстанавливаем локально, если удаление не прошло
        _restoreLocally(c);
      }
    }
  }

  // === Поиск/сортировка === (улучшенный: имя + цифры телефона, регистронезависимая сортировка)
  int _cmpCi(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());
  String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');

  List<Contact> get _filtered {
    final q = _query;
    final qDigits = _digits(q);

    Iterable<Contact> list = _all.where((c) {
      final nameHit = c.name.toLowerCase().contains(q);
      final phoneHit = qDigits.isEmpty ? false : _digits(c.phone).contains(qDigits);
      return nameHit || phoneHit;
    });

    if (_statusFilters.isNotEmpty) {
      list = list.where((c) => _statusFilters.contains(c.status));
    }

    final result = list.toList();
    switch (_sort) {
      case SortOption.nameAsc:
        result.sort((a, b) => _cmpCi(a.name, b.name));
        break;
      case SortOption.nameDesc:
        result.sort((a, b) => _cmpCi(b.name, a.name));
        break;
      case SortOption.dateAsc:
        result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case SortOption.dateDesc:
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom; // жестовая зона / home indicator
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final keyboardShown = viewInsets > 0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.sort), onPressed: _openSort),
          IconButton(icon: const Icon(Icons.filter_alt), onPressed: _openFilters),
        ],
      ),
      body: SafeArea(
        top: false, // AppBar уже учитывает верхний инсет
        bottom: true,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchController,
                builder: (_, value, __) => TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Поиск',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: value.text.isEmpty
                        ? null
                        : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceVariant,
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.circular(28), // капсула
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
              ),
            ),
            Expanded(child: _buildContactList()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => AddContactScreen(category: widget.category),
              transitionsBuilder: (_, animation, __, child) {
                const begin = Offset(0.0, 1.0);
                const end = Offset.zero;
                final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.ease));
                return SlideTransition(position: animation.drive(tween), child: child);
              },
            ),
          );
          if (saved == true) {
            await _loadContacts(reset: true);
            if (mounted) {
              showSuccessBanner('Контакт сохранён');
            }
          }
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Добавить контакт'),
      ),
    );
  }

  // Под-виджет для списка контактов
  Widget _buildContactList() {
    final contacts = _filtered;
    if (contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ничего не найдено'),
            if (_statusFilters.isNotEmpty || _query.isNotEmpty)
              TextButton(
                onPressed: () {
                  setState(() {
                    _query = '';
                    _searchController.clear();
                    _statusFilters.clear();
                  });
                },
                child: const Text('Сбросить фильтры'),
              ),
          ],
        ),
      );
    }
    return ListView.separated(
      key: PageStorageKey('ContactList:${widget.category}'),
      controller: _scroll,
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        8 + fabReserve, // ← безопасная зона + запас под FAB
      ),
      itemCount: contacts.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= contacts.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final c = contacts[index];
        final wrapperKey = (c.id != null) ? _keyFor(c) : null;
        final isHighlighted = (c.id != null && c.id == _highlightId);
        return RepaintBoundary(
          // изолируем перерисовку эффекта
          key: wrapperKey, // для ensureVisible
          child: _ContactCard(
            contact: c,
            onTap: () async {
              final result = await Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => ContactDetailsScreen(contact: c),
                  transitionsBuilder: (_, animation, __, child) {
                    const begin = Offset(1.0, 0.0);
                    const end = Offset.zero;
                    final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.ease));
                    return SlideTransition(position: animation.drive(tween), child: child);
                  },
                ),
              );
              if (!mounted) return;
              // адресное обновление
              if (result is Contact) {
                setState(() {
                  final i = _all.indexWhere((e) => e.id == result.id);
                  if (i >= 0) _all[i] = result;
                  _cleanupKeys();
                });
              } else if (result is Map && result['deletedId'] is int) {
                setState(() {
                  _all.removeWhere((e) => e.id == result['deletedId']);
                  _cleanupKeys();
                });
              }
            },
            pulse: isHighlighted,
            pulseSeed: _pulseSeed, // эффект «нажатия без нажатия»
            onLongPress: () => _showContactMenu(c),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 8),
    );
  }
}

class _ContactCard extends StatefulWidget {
  final Contact contact;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool pulse;
  final int pulseSeed; // триггер для перезапуска анимации
  const _ContactCard({
    required this.contact,
    this.onTap,
    this.onLongPress,
    this.pulse = false,
    required this.pulseSeed,
  });

  @override
  State<_ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends State<_ContactCard> with TickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _glowAnim; // для внутреннего мягкого свечения

  void _set(bool v) => setState(() => _pressed = v);

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: _ContactListScreenState.pulseDuration,
    );
    // последовательность: чуть сжаться -> вернуться
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.965).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.965, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 60,
      ),
    ]).animate(_pulseCtrl);
    // внутренний «блик» (быстрый всплеск и затухание)
    _glowAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOutQuart)),
        weight: 65,
      ),
    ]).animate(_pulseCtrl);
    if (widget.pulse) {
      _pulseCtrl.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(covariant _ContactCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.pulse && widget.pulse) {
      _pulseCtrl.forward(from: 0);
    }
    if (widget.pulse && oldWidget.pulseSeed != widget.pulseSeed) {
      _pulseCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  String _initialsFrom(String name) {
    final cleaned = name.trim();
    if (cleaned.isEmpty) return '?';
    final parts = cleaned.split(RegExp(r'\s+'));
    String first = parts[0];
    String? second = parts.length > 1 ? parts[1] : null;
    String takeFirstLetter(String s) {
      if (s.isEmpty) return '';
      return s.characters.first.toUpperCase();
    }
    final a = takeFirstLetter(first);
    final b = second == null ? '' : takeFirstLetter(second);
    final res = (a + b);
    return res.isEmpty ? '?' : res;
  }

  Color _avatarBgFor(String seed, ColorScheme scheme) {
    int h = 0;
    for (final r in seed.runes) {
      h = (h * 31 + r) & 0x7fffffff;
    }
    final hue = (h % 360).toDouble();
    final hsl = HSLColor.fromAHSL(1.0, hue, 0.45, 0.55);
    return hsl.toColor();
  }

  Widget _buildAvatar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initials = _initialsFrom(widget.contact.name);
    final bg = _avatarBgFor(widget.contact.name, scheme);
    return Semantics(
      label: 'Аватар контакта ${widget.contact.name}',
      child: CircleAvatar(
        backgroundColor: bg,
        child: Text(
          initials,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final border = BorderRadius.circular(12);
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        final glow = scheme.primary.withOpacity(0.14 * _glowAnim.value);
        final shadowColor = scheme.primary.withOpacity(0.20 * _glowAnim.value);
        final blur = 24 * _glowAnim.value + 0.0;
        return Transform.scale(
          scale: _scaleAnim.value,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: border,
              boxShadow: _glowAnim.value == 0
                  ? null
                  : [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: blur,
                  spreadRadius: 1.5 * _glowAnim.value,
                ),
              ],
            ),
            child: Stack(
              children: [
                _buildCard(context, border),
                if (_glowAnim.value > 0)
                  PositionedFill(
                    border: border,
                    color: glow,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard(BuildContext context, BorderRadius border) {
    const double kStatusReserve = 120;
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: Material(
        borderRadius: border,
        color: Theme.of(context).colorScheme.surfaceVariant,
        elevation: 2,
        child: InkWell(
          borderRadius: border,
          onTap: () {
            _set(false);
            widget.onTap?.call();
          },
          onLongPress: () {
            _set(false);
            widget.onLongPress?.call();
          },
          onTapDown: (_) => _set(true),
          onTapCancel: () => _set(false),
          onTapUp: (_) => _set(false),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: kStatusReserve),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildAvatar(context),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.contact.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.start,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.contact.phone,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final tag in widget.contact.tags)
                            Semantics(
                              label: 'Тег $tag',
                              child: Chip(
                                label: Text(
                                  tag,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: 10,
                                    color: ContactColors.tagTextColor(tag),
                                  ),
                                ),
                                backgroundColor: ContactColors.tagColor(tag),
                                visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Semantics(
                    label: 'Статус ${widget.contact.status}',
                    child: Chip(
                      label: Text(
                        widget.contact.status,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                      backgroundColor: ContactColors.statusColor(widget.contact.status),
                      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Простая обёртка для позиционирования свечения (чтобы не дублировать BoxDecoration)
class PositionedFill extends StatelessWidget {
  final BorderRadius border;
  final Color color;
  const PositionedFill({super.key, required this.border, required this.color});
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: border,
            color: color,
          ),
        ),
      ),
    );
  }
}

enum SortOption { nameAsc, nameDesc, dateAsc, dateDesc }
