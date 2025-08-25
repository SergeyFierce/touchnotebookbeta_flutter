import 'dart:async';
import 'package:flutter/material.dart';

import '../app.dart'; // для App.navigatorKey
import '../models/contact.dart';
import '../services/contact_database.dart';
import 'add_contact_screen.dart';

class ContactListScreen extends StatefulWidget {
  final String category; // singular value for DB
  final String title;    // display title
  final int? scrollToId; // к какому id проскроллить/подсветить при открытии

  const ContactListScreen({
    super.key,
    required this.category,
    required this.title,
    this.scrollToId,
  });

  @override
  State<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends State<ContactListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scroll = ScrollController();
  int _pulseSeed = 0; // триггер импульса для карточек

  // ключи карточек по id для ensureVisible
  final Map<int, GlobalKey> _itemKeys = {};

  Timer? _debounce;
  Timer? _snackTimer;

  // подсветка восстановленного контакта
  int? _highlightId;
  Timer? _highlightTimer;

  String _query = '';
  SortOption _sort = SortOption.dateDesc;
  Set<String> _statusFilters = {};

  List<Contact> _all = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  GlobalKey _keyFor(Contact c) {
    final id = c.id;
    if (id == null) return GlobalKey();
    return _itemKeys[id] ??= GlobalKey(debugLabel: 'contact_$id');
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
      _pulseSeed++; // <- новый триггер для импульса
    });

    _highlightTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted && _highlightId == id) {
        setState(() => _highlightId = null);
      }
    });
  }


  Future<void> _loadContacts() async {
    final contacts =
    await ContactDatabase.instance.contactsByCategory(widget.category);
    if (!mounted) return;
    setState(() => _all = contacts);

    // автоскролл/подсветка при открытии по scrollToId
    if (widget.scrollToId != null && _all.any((e) => e.id == widget.scrollToId)) {
      final id = widget.scrollToId!;
      await _maybeScrollTo(id);
      _flashHighlight(id);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _snackTimer?.cancel();
    _highlightTimer?.cancel();
    _searchController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _query = value.toLowerCase();
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
    final statuses = ['Активный', 'Пассивный', 'Потерянный', 'Холодный', 'Тёплый'];
    final selected = Set<String>.from(_statusFilters);
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setStateSB) {
              return Column(
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
                  TextButton(
                    onPressed: () => Navigator.pop(context, selected),
                    child: const Text('Применить'),
                  ),
                ],
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
                leading: const Icon(Icons.delete),
                title: const Text('Удалить'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        );
      },
    );
    if (action == 'delete') {
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

  /// Переходит к нужной категории (если надо) и подсвечивает восстановленный контакт.
  Future<void> _goToRestored(Contact restored, int restoredId) async {
    // уже на нужной категории
    if (mounted && widget.category == restored.category) {
      await _loadContacts();
      await _maybeScrollTo(restoredId);
      _flashHighlight(restoredId);
      return;
    }

    // пушим новую страницу категории, она сама проскроллит и подсветит по scrollToId
    final String title = _titleForCategory(restored.category);
    App.navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ContactListScreen(
          category: restored.category,
          title: title,
          scrollToId: restoredId,
        ),
      ),
    );
  }

  String _titleForCategory(String cat) {
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

  /// Удаляет контакт и показывает SnackBar с Undo + индикатором и обратным отсчётом.
  Future<void> _deleteWithUndo(Contact c) async {
    // 1) Удаляем из БД (если есть id)
    if (c.id != null) {
      await ContactDatabase.instance.delete(c.id!);
    }
    // 2) Удаляем из списка и перерисовываем
    setState(() {
      _all.removeWhere((e) => e.id == c.id);
    });

    // 3) Snackbar с ручным таймером + Undo
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    const duration = Duration(seconds: 4);

    messenger.clearSnackBars();
    _snackTimer?.cancel();

    final endTime = DateTime.now().add(duration);
    final controller = messenger.showSnackBar(
      SnackBar(
        duration: const Duration(days: 1), // закроем вручную таймером
        content: _UndoSnackContent(endTime: endTime, duration: duration),
        action: SnackBarAction(
          label: 'Отменить',
          onPressed: () async {
            _snackTimer?.cancel();
            messenger.hideCurrentSnackBar();

            int? restoredId;
            try {
              // восстановить с тем же id
              restoredId = await ContactDatabase.instance.insert(c);
            } catch (_) {
              // конфликт id — вставим без id
              restoredId =
              await ContactDatabase.instance.insert(c.copyWith(id: null));
            }

            await _goToRestored(c, restoredId!);
          },
        ),
      ),
    );

    _snackTimer = Timer(
      endTime.difference(DateTime.now()),
          () => controller.close(),
    );
  }

  List<Contact> get _filtered {
    var list = _all.where((c) => c.name.toLowerCase().contains(_query));
    if (_statusFilters.isNotEmpty) {
      list = list.where((c) => _statusFilters.contains(c.status));
    }
    final result = list.toList();
    switch (_sort) {
      case SortOption.nameAsc:
        result.sort((a, b) => a.name.compareTo(b.name));
        break;
      case SortOption.nameDesc:
        result.sort((a, b) => b.name.compareTo(a.name));
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

  Color _statusColor(String status) {
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

  Color _tagColor(String tag) {
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

  Color _tagTextColor(String tag) {
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

  @override
  Widget build(BuildContext context) {
    final contacts = _filtered;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(widget.title),
        actions: [
          IconButton(icon: const Icon(Icons.sort), onPressed: _openSort),
          IconButton(icon: const Icon(Icons.filter_alt), onPressed: _openFilters),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Поиск',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: contacts.isEmpty
                ? Center(
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
            )
                : ListView.separated(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemBuilder: (context, index) {
                final c = contacts[index];
                final wrapperKey = (c.id != null) ? _keyFor(c) : null;
                final isHighlighted = (c.id != null && c.id == _highlightId);

                return Dismissible(
                  key: ValueKey(
                    c.id ?? '${c.name}_${c.createdAt.millisecondsSinceEpoch}',
                  ),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    color: Colors.red,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) async => true,
                  onDismissed: (_) async {
                    await _deleteWithUndo(c);
                  },
                  child: RepaintBoundary( // изолируем перерисовку эффекта
                    key: wrapperKey, // для ensureVisible
                    child: _ContactCard(
                      contact: c,
                      pulse: isHighlighted,
                      pulseSeed: _pulseSeed,// ← эффект «нажатия без нажатия»
                      onLongPress: () => _showContactMenu(c),
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemCount: contacts.length,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddContactScreen(category: widget.category),
            ),
          );
          if (saved == true) {
            await _loadContacts();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Контакт сохранён')),
              );
            }
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
    );
  }
}

class _ContactCard extends StatefulWidget {
  final Contact contact;
  final VoidCallback? onLongPress;
  final bool pulse;
  final int pulseSeed; // <- NEW

  const _ContactCard({
    required this.contact,
    this.onLongPress,
    this.pulse = false,
    required this.pulseSeed, // <- NEW (сделаем обязательным)
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
      duration: const Duration(milliseconds: 3250),
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

    // если уже пришли в состоянии подсветки (напр. при автоскролле) — сыграем сразу
    if (widget.pulse) {
      _pulseCtrl.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(covariant _ContactCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 1) флаг стал true -> запуск
    if (!oldWidget.pulse && widget.pulse) {
      _pulseCtrl.forward(from: 0);
    }
    // 2) сменился seed при pulse=true -> гарантированный перезапуск
    if (widget.pulse && oldWidget.pulseSeed != widget.pulseSeed) {
      _pulseCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final border = BorderRadius.circular(12);
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        // мягкий внутренний «блик»
        final glow = scheme.primary.withOpacity(0.14 * _glowAnim.value);
        final shadowColor = scheme.primary.withOpacity(0.20 * _glowAnim.value);
        final blur = 24 * _glowAnim.value + 0.0;

        return Transform.scale(
          scale: _scaleAnim.value, // эффект «как при тапе»
          child: Container(
            decoration: BoxDecoration(
              borderRadius: border,
              // тонкая подсветка изнутри
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
                // сама карточка
                _buildCard(context, border),
                // тонкий внутренний слой, «заливающий» фон на миг
                if (_glowAnim.value > 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: border,
                          color: glow,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard(BuildContext context, BorderRadius border) {
    return Material(
      borderRadius: border,
      color: Theme.of(context).colorScheme.surfaceVariant,
      elevation: 2,
      child: InkWell(
        borderRadius: border,
        onTap: () {},
        onLongPress: () {
          _set(false);
          widget.onLongPress?.call();
        },
        onTapDown: (_) => _set(true),
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Имя + теги справа
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.contact.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final tag in widget.contact.tags)
                          Chip(
                            label: Text(
                              tag,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontSize: 10, color: _tagTextColor(tag)),
                            ),
                            backgroundColor: _tagColor(tag),
                            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(widget.contact.phone, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Chip(
                label: Text(
                  widget.contact.status,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10, color: Colors.white),
                ),
                backgroundColor: _statusColor(widget.contact.status),
                visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
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

  Color _tagColor(String tag) {
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

  Color _tagTextColor(String tag) {
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

/// Контент SnackBar с обратным отсчётом и прогресс-баром.
class _UndoSnackContent extends StatefulWidget {
  final DateTime endTime;
  final Duration duration;
  const _UndoSnackContent({required this.endTime, required this.duration});

  @override
  State<_UndoSnackContent> createState() => _UndoSnackContentState();
}

class _UndoSnackContentState extends State<_UndoSnackContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  double _fractionRemaining(DateTime now) {
    final total = widget.duration.inMilliseconds;
    final left = widget.endTime.difference(now).inMilliseconds;
    if (total <= 0) return 0;
    return left <= 0 ? 0 : (left / total).clamp(0.0, 1.0);
  }

  void _syncAndRun() {
    final now = DateTime.now();
    final frac = _fractionRemaining(now); // 0..1
    final msLeft = (widget.duration.inMilliseconds * frac).round();

    _ctrl.stop();
    _ctrl.value = frac; // мгновенно, без «вспышки»
    if (msLeft > 0) {
      _ctrl.animateTo(
        0.0,
        duration: Duration(milliseconds: msLeft),
        curve: Curves.linear,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
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
  void didUpdateWidget(covariant _UndoSnackContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endTime != widget.endTime ||
        oldWidget.duration != widget.duration) {
      _syncAndRun();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _ctrl.value; // 1.0 -> 0.0
    final secondsLeft =
    (value * widget.duration.inSeconds).ceil().clamp(0, 999);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Контакт удалён')),
            Text('$secondsLeft c'),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: value),
      ],
    );
  }
}

enum SortOption { nameAsc, nameDesc, dateAsc, dateDesc }
