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

class _NotesListScreenState extends State<NotesListScreen> {
  final _db = ContactDatabase.instance;
  List<Note> _notes = [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    if (widget.contact.id == null) return;
    final notes = await _db.notesByContact(widget.contact.id!);
    setState(() => _notes = notes);
  }

  Future<void> _addNote() async {
    if (widget.contact.id == null) return;
    final note = await Navigator.push<Note>(
      context,
      MaterialPageRoute(
        builder: (_) => AddNoteScreen(contactId: widget.contact.id!),
      ),
    );
    if (note != null) {
      await _loadNotes();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Заметка добавлена')));
    }
  }

  Future<void> _openDetails(Note note) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteDetailsScreen(note: note)),
    );
    if (result is Map && result['deleted'] is Note) {
      final deleted = result['deleted'] as Note;
      await _loadNotes();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Заметка удалена'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              final id = await _db.insertNote(deleted.copyWith(id: null));
              await _loadNotes();
              if (!mounted) return;
              final restored = deleted.copyWith(id: id);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => NoteDetailsScreen(note: restored)),
              );
            },
          ),
        ),
      );
    } else {
      await _loadNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Заметки')),
      body: _notes.isEmpty
          ? const Center(child: Text('Нет заметок'))
          : ListView.builder(
              itemCount: _notes.length,
              itemBuilder: (context, i) {
                final n = _notes[i];
                return ListTile(
                  title: Text(n.text),
                  subtitle: Text(DateFormat('dd.MM.yyyy HH:mm').format(n.createdAt)),
                  onTap: () => _openDetails(n),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNote,
        child: const Icon(Icons.add),
      ),
    );
  }
}
