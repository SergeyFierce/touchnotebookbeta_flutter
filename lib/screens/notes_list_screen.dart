import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:overlay_support/overlay_support.dart';

import '../models/contact.dart';
import '../models/note.dart';
import '../services/contact_database.dart';
import 'add_note_screen.dart';
import 'note_details_screen.dart';
import '../widgets/system_notifications.dart';

class NotesListScreen extends StatefulWidget {
  final Contact contact;
  const NotesListScreen({super.key, required this.contact});

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

// Оставляем только два варианта сортировки
enum SortNotesOption { dateDesc, dateAsc }

class _NotesListScreenState extends State<NotesListScreen> {
  final _db = ContactDatabase.instance;
  final ScrollController _scroll = ScrollController();

  // === данные ===
  List<Note> _notes = [];

  static const int _pageSize = 20;
  int _page = 0;
  bool _isLoading = false;
  bool _hasMore = true;

  // --- сортировка ---
  SortNotesOption _sort = SortNotesOption.dateDesc;

  // Кэш отсортированного списка, чтобы не пересортировывать на каждый build
  List<Note> _sortedNotes = const [];

  // --- подсветка и автоскролл ---
  final LinkedHashMap<int, GlobalKey> _itemKeys = LinkedHashMap<int, GlobalKey>();
  static const int _maxKeys = 300;
  int? _highlightId;
  int _pulseSeed = 0;

  // overlay_support баннер для Undo; НЕ закрываем принудительно в dispose
  OverlaySupportEntry? _undoBanner;

  @override
  void initState() {
    super.initState();
    _loadNotes(reset: true);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    // Раньше тут был _undoBanner?.dismiss(); — удалили, чтобы баннер не исчезал при переходе
    super.dispose();
  }

  // === загрузка ===

  Future<void> _loadNotes({bool reset = false}) async {
    if (reset) {
      setState(() {
        _notes.clear();
        _sortedNotes = const [];
        _page = 0;
        _hasMore = true;
        _itemKeys.clear();
      });
    }
    await _loadMoreNotes();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadMoreNotes();
    }
  }

  Future<void> _loadMoreNotes() async {
    if (widget.contact.id == null || _isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    List<Note> pageNotes = [];
    try {
      pageNotes = await _db.notesByContactPaged(
        widget.contact.id!,
        limit: _pageSize,
        offset: _page * _pageSize,
      );
    } catch (e) {
      _showErrorBanner('Не удалось загрузить заметки');
    }

    if (!mounted) return;

    setState(() {
      final existingIds = _notes.map((e) => e.id).toSet();
      final unique = pageNotes.where((n) => !existingIds.contains(n.id)).toList();

      _notes.addAll(unique);
      _page++;
      _isLoading = false;
      if (pageNotes.length < _pageSize) _hasMore = false;

      _rebuildSorted();
    });
  }

  // ----- сортировка (кэшируем результат) -----
  void _rebuildSorted() {
    final list = [..._notes];
    switch (_sort) {
      case SortNotesOption.dateDesc:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortNotesOption.dateAsc:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
    }
    _sortedNotes = list;
  }

  Future<void> _openSort() async {
    final result = await showModalBottomSheet<SortNotesOption>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<SortNotesOption>(
                title: const Text('Сначала новые'),
                value: SortNotesOption.dateDesc,
                groupValue: _sort,
                onChanged: (v) => Navigator.pop(context, v),
              ),
              RadioListTile<SortNotesOption>(
                title: const Text('Сначала старые'),
                value: SortNotesOption.dateAsc,
                groupValue: _sort,
                onChanged: (v) => Navigator.pop(context, v),
              ),
            ],
          ),
        );
      },
    );
    if (result != null) {
      setState(() {
        _sort = result;
        _rebuildSorted();
      });
    }
  }

  GlobalKey _keyFor(Note n) {
    if (n.id == null) return GlobalKey();
    if (_itemKeys.length >= _maxKeys && !_itemKeys.containsKey(n.id)) {
      final oldestKey = _itemKeys.keys.first;
      _itemKeys.remove(oldestKey);
    }
    return _itemKeys[n.id!] ??= GlobalKey(debugLabel: 'note_${n.id}');
  }

  Future<void> _maybeScrollTo(int id) async {
    await Future.delayed(Duration.zero);
    final key = _itemKeys[id];
    final ctx = key?.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        alignment: 0.1,
      );
    }
  }

  void _flashHighlight(int id) {
    setState(() {
      _highlightId = id;
      _pulseSeed++;
    });
    Timer(const Duration(milliseconds: 1800), () {
      if (mounted && _highlightId == id) {
        setState(() => _highlightId = null);
      }
    });
  }

  Future<void> _addNote() async {
    if (widget.contact.id == null) return;
    final note = await Navigator.push<Note>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => AddNoteScreen(contactId: widget.contact.id!),
        transitionsBuilder: (_, animation, __, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          final tween =
          Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.ease));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
    if (note != null) {
      await _loadNotes(reset: true);
      if (!mounted) return;
      showSuccessBanner('Заметка добавлена'); // overlay_support — живёт через роуты
      if (note.id != null) {
        await _maybeScrollTo(note.id!);
        _flashHighlight(note.id!);
      }
    }
  }

  Future<void> _openDetails(Note note) async {
    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => NoteDetailsScreen(note: note),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );

    if (result is Map && result.isNotEmpty) {
      if (result['deleted'] is Note) {
        await _loadNotes(reset: true);
        if (!mounted) return;
      } else if (result['restored'] is Note) {
        final restored = result['restored'] as Note;
        await _loadNotes(reset: true);
        if (!mounted) return;
        if (restored.id != null) {
          await _maybeScrollTo(restored.id!);
          _flashHighlight(restored.id!);
        }
      } else if (result['updated'] == true) {
        await _loadNotes(reset: true);
      }
    }
  }

  Future<void> _deleteNoteWithUndo(Note n) async {
    if (n.id != null) {
      try {
        await _db.deleteNote(n.id!);
      } catch (_) {
        _showErrorBanner('Не удалось удалить заметку');
        return;
      }
    }
    setState(() {
      _notes.removeWhere((e) => e.id == n.id);
      _rebuildSorted();
    });

    if (!mounted) return;
    const duration = Duration(seconds: 4);

    // Закроем предыдущий, если есть
    _undoBanner?.dismiss();

    _undoBanner = showUndoBanner(
      message: 'Заметка удалена',
      duration: duration,
      icon: Icons.delete_outline,
      onUndo: () async {
        _undoBanner = null;
        try {
          final id = await _db.insertNote(n.copyWith(id: null));
          await _loadNotes(reset: true);
          if (!mounted) return;
          await _maybeScrollTo(id);
          _flashHighlight(id);
        } catch (_) {
          _showErrorBanner('Не удалось восстановить заметку');
        }
      },
    );

    HapticFeedback.mediumImpact();
  }

  Future<void> _showNoteMenu(Note n) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Оставляем только «Детали заметки» и «Удалить»
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Детали заметки'),
              onTap: () => Navigator.pop(context, 'details'),
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Удалить'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (action == 'details') {
      await _openDetails(n);
    } else if (action == 'delete') {
      HapticFeedback.selectionClick();
      await _deleteNoteWithUndo(n);
    }
  }

  Widget _buildList(List<Note> data) {
    final listView = data.isEmpty
        ? ListView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      children: [
        const SizedBox(height: 32),
        Center(
          child: Column(
            children: [
              const Text('Нет заметок'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _addNote,
                icon: const Icon(Icons.add),
                label: const Text('Добавить заметку'),
              ),
            ],
          ),
        ),
      ],
    )
        : ListView.separated(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: data.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        if (i >= data.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final n = data[i];
        final k = (n.id != null) ? _keyFor(n) : null;
        final isHighlighted = (n.id != null && n.id == _highlightId);
        return KeyedSubtree(
          key: k,
          child: _NoteCard(
            note: n,
            pulse: isHighlighted,
            pulseSeed: _pulseSeed,
            onTap: () => _openDetails(n),
            onLongPress: () {
              HapticFeedback.selectionClick();
              _showNoteMenu(n);
            },
          ),
        );
      },
    );

    return RefreshIndicator(
      onRefresh: () => _loadNotes(reset: true),
      child: listView,
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _sortedNotes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Заметки'),
        actions: [
          IconButton(
            tooltip: 'Сортировка',
            icon: const Icon(Icons.sort),
            onPressed: _openSort,
          ),
        ],
      ),
      body: _buildList(data),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNote,
        label: const Text('Добавить заметку'),
      ),
    );
  }

  void _showErrorBanner(String message) {
    // overlay_support уведомление — не зависит от текущего экрана
    showSimpleNotification(
      Text(message),
      background: Theme.of(context).colorScheme.error,
      foreground: Theme.of(context).colorScheme.onError,
      leading: const Icon(Icons.error_outline),
      elevation: 2,
      autoDismiss: true,
      slideDismissDirection: DismissDirection.up,
    );
  }
}

// ==== Карточка заметки с риплом, бордером и эффектом «пульса» ====

class _NoteCard extends StatefulWidget {
  final Note note;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool pulse;
  final int pulseSeed;

  const _NoteCard({
    required this.note,
    this.onTap,
    this.onLongPress,
    required this.pulse,
    required this.pulseSeed,
  });

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _glowAnim;
  bool _pressed = false;

  void _set(bool v) => setState(() => _pressed = v);

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3250),
    );

    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.965)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.965, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 60,
      ),
    ]).animate(_pulseCtrl);

    _glowAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOutQuart)),
        weight: 65,
      ),
    ]).animate(_pulseCtrl);

    if (widget.pulse) _pulseCtrl.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant _NoteCard oldWidget) {
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: Theme.of(context).dividerColor),
    );

    // Русская локаль + время
    final date = DateFormat('dd.MM.yyyy HH:mm', 'ru').format(widget.note.createdAt);

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        final shadowColor = scheme.primary.withOpacity(0.20 * _glowAnim.value);
        final blur = 24 * _glowAnim.value + 0.0;

        return Transform.scale(
          scale: _scaleAnim.value * (_pressed ? 0.98 : 1.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
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
            child: Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 4),
              shape: border,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onTap,
                onLongPress: widget.onLongPress,
                onTapDown: (_) => _set(true),
                onTapCancel: () => _set(false),
                onTapUp: (_) => _set(false),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.note.text,
                              style: Theme.of(context).textTheme.bodyLarge,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.event, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  date,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Theme.of(context).hintColor),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
