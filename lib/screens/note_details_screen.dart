import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:overlay_support/overlay_support.dart';
import '../models/note.dart';
import '../services/contact_database.dart';
import '../widgets/system_notifications.dart';

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
  OverlaySupportEntry? _undoBanner;

  @override
  void initState() {
    super.initState();
    _note = widget.note;
    _loadFromNote();
  }

  @override
  void dispose() {
    _textController.dispose();
    _undoBanner = null;
    _undoBanner?.dismiss();
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
      locale: const Locale('ru'),
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

    showSuccessBanner('Заметка сохранена');

    if (!mounted) return;
    Navigator.pop(context, {'updated': true});
  }


  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить заметку?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;

    if (_note.id != null) {
      await ContactDatabase.instance.deleteNote(_note.id!);
    }

    const duration = Duration(seconds: 4);
    _undoBanner?.dismiss();

    _undoBanner = showUndoBanner(
      message: 'Заметка удалена',
      duration: duration,
      icon: Icons.delete_outline,
      onUndo: () async {
        _undoBanner = null;
        final newId = await ContactDatabase.instance.insertNote(
          _note.copyWith(id: null),
        );
        _note = _note.copyWith(id: newId);
        _savedSnapshot = _note;
        if (!mounted) return;
        setState(() {
          _isEditing = false;
        });
        Navigator.pop(context, {'restored': _note});
      },
    );

    Future.delayed(duration, () {
      if (mounted) {
        _undoBanner = null;
        Navigator.pop(context, {'deleted': _note});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd.MM.yyyy').format(_date);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Закрыть',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Заметка'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Сохранить',
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
                    title: 'Текст',
                    children: [
                      TextFormField(
                        controller: _textController,
                        minLines: 1,
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                        decoration: _outlinedDec(
                          label: 'Текст заметки*',
                          hint: 'Введите текст',
                          prefixIcon: Icons.notes_outlined,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите текст' : null,
                        onChanged: (_) => setState(() => _isEditing = _isDirty),
                      ),
                    ],
                  ),
                  _sectionCard(
                    title: 'Дата',
                    children: [
                      _borderedTile(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          leading: const Icon(Icons.event_outlined),
                          title: const Text('Дата добавления'),
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
          child: const Text('Удалить заметку'),
        ),
      ),

    );
  }
}

