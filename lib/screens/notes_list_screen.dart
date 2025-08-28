import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/contact.dart';
import '../models/note.dart';
import '../services/contact_database.dart';
import 'add_note_screen.dart';
import 'note_details_screen.dart';

class NotesListScreen extends StatefulWidget {
  final Contact contact;
  const NotesListScreen({super.key, required this.contact});

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

enum SortNotesOption { dateDesc, dateAsc, textAsc, textDesc }

class _NotesListScreenState extends State<NotesListScreen> {
  final _db = ContactDatabase.instance;
  List<Note> _notes = [];

  static const int _pageSize = 20;
  int _page = 0;
  bool _isLoading = false;
  bool _hasMore = true;

  // --- сортировка ---
  SortNotesOption _sort = SortNotesOption.dateDesc;

  // --- для эффекта подсветки и автоскролла (как в ContactList) ---
  final ScrollController _scroll = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};
  int? _highlightId;
  int _pulseSeed = 0;
  Timer? _snackTimer;

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
    _snackTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadNotes({bool reset = false}) async {
    if (reset) {
      _notes.clear();
      _page = 0;
      _hasMore = true;
    }
    await _loadMoreNotes();
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 200) {
      _loadMoreNotes();
    }
  }

  Future<void> _loadMoreNotes() async {
    if (widget.contact.id == null || _isLoading || !_hasMore) return;
    setState(() => _isLoading = true);
    final notes = await _db.notesByContactPaged(
      widget.contact.id!,
      limit: _pageSize,
      offset: _page * _pageSize,
    );
    setState(() {
      _notes.addAll(notes);
      _isLoading = false;
      _page++;
      if (notes.length < _pageSize) {
        _hasMore = false;
      }
    });
  }

  // ----- сортировка -----
  List<Note> get _sorted {
    final list = [..._notes];
    switch (_sort) {
      case SortNotesOption.dateDesc:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortNotesOption.dateAsc:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case SortNotesOption.textAsc:
        list.sort((a, b) => a.text.toLowerCase().compareTo(b.text.toLowerCase()));
        break;
      case SortNotesOption.textDesc:
        list.sort((a, b) => b.text.toLowerCase().compareTo(a.text.toLowerCase()));
        break;
    }
    return list;
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
                title: const Text('Новые сверху'),
                value: SortNotesOption.dateDesc,
                groupValue: _sort,
                onChanged: (v) => Navigator.pop(context, v),
              ),
              RadioListTile<SortNotesOption>(
                title: const Text('Старые сверху'),
                value: SortNotesOption.dateAsc,
                groupValue: _sort,
                onChanged: (v) => Navigator.pop(context, v),
              ),
              RadioListTile<SortNotesOption>(
                title: const Text('Текст A→Я'),
                value: SortNotesOption.textAsc,
                groupValue: _sort,
                onChanged: (v) => Navigator.pop(context, v),
              ),
              RadioListTile<SortNotesOption>(
                title: const Text('Текст Я→A'),
                value: SortNotesOption.textDesc,
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

  GlobalKey _keyFor(Note n) {
    if (n.id == null) return GlobalKey();
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
          final tween = Tween(begin: begin, end: end)
              .chain(CurveTween(curve: Curves.ease));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
    if (note != null) {
      await _loadNotes(reset: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Заметка добавлена')));
      // скролл и подсветка новой заметки (если у неё есть id)
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

    // поддержка трёх сценариев: удалено, восстановлено, обновлено
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
      await _db.deleteNote(n.id!);
    }
    setState(() => _notes.removeWhere((e) => e.id == n.id));

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    const duration = Duration(seconds: 4);

    messenger.clearSnackBars();
    _snackTimer?.cancel();

    final endTime = DateTime.now().add(duration);
    final controller = messenger.showSnackBar(
      SnackBar(
        duration: const Duration(days: 1),
        content: _UndoSnackContentNote(endTime: endTime, duration: duration),
        action: SnackBarAction(
          label: 'Отменить',
          onPressed: () async {
            _snackTimer?.cancel();
            messenger.hideCurrentSnackBar();

            final id = await _db.insertNote(n.copyWith(id: null));
            await _loadNotes(reset: true);
            if (!mounted) return;

            await _maybeScrollTo(id);
            _flashHighlight(id);
          },
        ),
      ),
    );

    _snackTimer =
        Timer(endTime.difference(DateTime.now()), () => controller.close());
  }

  Future<void> _showNoteMenu(Note n) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
      await _deleteNoteWithUndo(n);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _sorted;

    final content = data.isEmpty
        ? const Center(child: Text('Нет заметок'))
        : ListView.separated(
      controller: _scroll,
      physics: const BouncingScrollPhysics(),
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
            onLongPress: () => _showNoteMenu(n),
          ),
        );
      },
    );

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
      body: content,
      floatingActionButton: FloatingActionButton(
        onPressed: _addNote,
        child: const Icon(Icons.add),
      ),
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

    final date = DateFormat('dd.MM.yyyy').format(widget.note.createdAt); // без времени

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        final glow = scheme.primary.withOpacity(0.14 * _glowAnim.value);
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

/// Контент SnackBar с обратным отсчётом (для заметок)
class _UndoSnackContentNote extends StatefulWidget {
  final DateTime endTime;
  final Duration duration;
  const _UndoSnackContentNote({required this.endTime, required this.duration});

  @override
  State<_UndoSnackContentNote> createState() => _UndoSnackContentNoteState();
}

class _UndoSnackContentNoteState extends State<_UndoSnackContentNote>
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
    final frac = _fractionRemaining(now);
    final msLeft = (widget.duration.inMilliseconds * frac).round();

    _ctrl.stop();
    _ctrl.value = frac;
    if (msLeft > 0) {
      _ctrl.animateTo(0.0,
          duration: Duration(milliseconds: msLeft), curve: Curves.linear);
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
  void didUpdateWidget(covariant _UndoSnackContentNote oldWidget) {
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
    final value = _ctrl.value;
    final secondsLeft =
    (value * widget.duration.inSeconds).ceil().clamp(0, 999);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [const Expanded(child: Text('Заметка удалена')), Text('$secondsLeft c')]),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: value),
      ],
    );
  }
}
