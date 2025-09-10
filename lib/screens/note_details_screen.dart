import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app.dart'; // для App.navigatorKey
import '../models/note.dart';
import '../services/contact_database.dart';
import '../l10n/app_localizations.dart';

class NoteDetailsScreen extends StatefulWidget {
  final Note note;
  const NoteDetailsScreen({super.key, required this.note});

  @override
  State<NoteDetailsScreen> createState() => _NoteDetailsScreenState();
}

class _NoteDetailsScreenState extends State<NoteDetailsScreen>
    with SingleTickerProviderStateMixin {
  late Note _note;          // актуальная заметка на экране
  late Note _savedSnapshot; // «последняя сохранённая» версия

  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  DateTime _date = DateTime.now();

  bool _isEditing = false;
  Timer? _snackTimer;

  @override
  void initState() {
    super.initState();
    _note = widget.note;
    _loadFromNote();
  }

  @override
  void dispose() {
    _textController.dispose();
    _snackTimer?.cancel();
    super.dispose();
  }

  // ==== UI helpers (как в AddNote) ====

  InputDecoration _outlinedDec({
    required String label,
    String? hint,
    IconData? prefixIcon,
  }) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _borderedTile({required Widget child}) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      ),
    );
  }

  // ==== загрузка/состояние ====

  void _loadFromNote() {
    _textController.text = _note.text;
    _date = _note.createdAt;
    _savedSnapshot = _note;
    _isEditing = false; // режим просмотра по умолчанию
    setState(() {});
  }

  bool get _isDirty {
    return _textController.text.trim() != _savedSnapshot.text ||
        !_sameDay(_date, _savedSnapshot.createdAt);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ==== действия ====

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: now,
      locale: Localizations.localeOf(context),
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(picked.year, picked.month, picked.day); // только дата
        _isEditing = _isDirty;
      });
    }
  }

  bool get _canSave => _isDirty && (_formKey.currentState?.validate() ?? false);

  Future<void> _save() async {
    if (!_canSave) return;
    final updated = _note.copyWith(
      text: _textController.text.trim(),
      createdAt: _date,
    );
    await ContactDatabase.instance.updateNote(updated);
    _note = updated;
    _savedSnapshot = updated;
    setState(() => _isEditing = false);

    // ✅ показываем SnackBar так, чтобы он остался после pop
    final rootCtx = App.navigatorKey.currentContext;
    if (rootCtx != null) {
      final l10nRoot = AppLocalizations.of(rootCtx)!;
      ScaffoldMessenger.of(rootCtx).showSnackBar(
        SnackBar(content: Text(l10nRoot.noteSaved)),
      );
    }

    if (!mounted) return;
    Navigator.pop(context, {'updated': true});
  }


  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteNoteQuestion),
        content: Text(l10n.deleteNoteWarning),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    if (_note.id != null) {
      await ContactDatabase.instance.deleteNote(_note.id!);
    }

    const duration = Duration(seconds: 4);
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    _snackTimer?.cancel();

    final endTime = DateTime.now().add(duration);
    final controller = messenger.showSnackBar(
      SnackBar(
        duration: const Duration(days: 1),
        content: _UndoSnackContentLocal(endTime: endTime, duration: duration),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () async {
            _snackTimer?.cancel();
            messenger.hideCurrentSnackBar();

            final newId = await ContactDatabase.instance.insertNote(
              _note.copyWith(id: null),
            );
            _note = _note.copyWith(id: newId);
            _savedSnapshot = _note;
            setState(() {
              _isEditing = false;
            });
            if (mounted) {
              Navigator.pop(context, {'restored': _note});
            }
          },
        ),
      ),
    );

    _snackTimer = Timer(endTime.difference(DateTime.now()), () => controller.close());

    Future.delayed(duration, () {
      if (mounted) {
        Navigator.pop(context, {'deleted': _note});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dateStr = DateFormat('dd.MM.yyyy').format(_date);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.close,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.note),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: l10n.save,
              icon: const Icon(Icons.check),
              onPressed: _canSave ? _save : null,
            ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  _sectionCard(
                    title: l10n.text,
                    children: [
                      TextFormField(
                        controller: _textController,
                        minLines: 1,
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                        decoration: _outlinedDec(
                          label: l10n.noteTextLabel,
                          hint: l10n.enterText,
                          prefixIcon: Icons.notes_outlined,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? l10n.enterText : null,
                        onChanged: (_) => setState(() => _isEditing = _isDirty),
                      ),
                    ],
                  ),
                  _sectionCard(
                    title: l10n.date,
                    children: [
                      _borderedTile(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          leading: const Icon(Icons.event_outlined),
                          title: Text(l10n.dateAdded),
                          subtitle: Text(dateStr),
                          trailing: const Icon(Icons.arrow_drop_down),
                          onTap: _pickDate,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: _delete,
          child: Text(l10n.deleteNote),
        ),
      ),

    );
  }
}

/// Локальный контент SnackBar с обратным отсчётом (экран деталей заметки)
class _UndoSnackContentLocal extends StatefulWidget {
  final DateTime endTime;
  final Duration duration;
  const _UndoSnackContentLocal({required this.endTime, required this.duration});

  @override
  State<_UndoSnackContentLocal> createState() => _UndoSnackContentLocalState();
}

class _UndoSnackContentLocalState extends State<_UndoSnackContentLocal>
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
      _ctrl.animateTo(0.0, duration: Duration(milliseconds: msLeft), curve: Curves.linear);
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
  void didUpdateWidget(covariant _UndoSnackContentLocal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endTime != widget.endTime || oldWidget.duration != widget.duration) {
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
    final secondsLeft = (value * widget.duration.inSeconds).ceil().clamp(0, 999);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Expanded(child: Text(l10n.noteDeleted)), Text('$secondsLeft ${l10n.secondsShort}')]),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: value),
      ],
    );
  }
}
