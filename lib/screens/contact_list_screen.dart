import 'dart:async';

import 'package:flutter/material.dart';

import '../models/contact.dart';
import '../services/contact_database.dart';
import 'add_contact_screen.dart';

class ContactListScreen extends StatefulWidget {
  final String category; // singular value for DB
  final String title; // display title

  const ContactListScreen({
    super.key,
    required this.category,
    required this.title,
  });

  @override
  State<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends State<ContactListScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  SortOption _sort = SortOption.dateDesc;
  Set<String> _statusFilters = {};

  List<Contact> _all = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final contacts =
    await ContactDatabase.instance.contactsByCategory(widget.category);
    setState(() => _all = contacts);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
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

    // 3) Показываем snackbar с Undo + таймер
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    const duration = Duration(seconds: 4);

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        content: _UndoSnackContent(duration: duration),
        action: SnackBarAction(
          label: 'Отменить',
          onPressed: () async {
            // Пытаемся вернуть с прежним id.
            try {
              final newRowId = await ContactDatabase.instance.insert(c);
              final restored = c.id == null ? c.copyWith(id: newRowId) : c;
              setState(() {
                _all.add(restored);
              });
            } catch (_) {
              // На случай конфликта id — вставляем без id (сгенерируется новый)
              final newId =
              await ContactDatabase.instance.insert(c.copyWith(id: null));
              setState(() {
                _all.add(c.copyWith(id: newId));
              });
            }
          },
        ),
      ),
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
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemBuilder: (context, index) {
                final c = contacts[index];
                return Dismissible(
                  key: ValueKey(c.id ??
                      '${c.name}_${c.createdAt.millisecondsSinceEpoch}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    color: Colors.red,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    // Можно запросить подтверждение, если хочешь
                    return true;
                  },
                  onDismissed: (_) async {
                    await _deleteWithUndo(c);
                  },
                  child: _ContactCard(
                    contact: c,
                    onLongPress: () => _showContactMenu(c),
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
              builder: (context) =>
                  AddContactScreen(category: widget.category),
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
  const _ContactCard({required this.contact, this.onLongPress});

  @override
  State<_ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends State<_ContactCard> {
  bool _pressed = false;

  void _set(bool v) => setState(() => _pressed = v);

  @override
  Widget build(BuildContext context) {
    final border = BorderRadius.circular(12);
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 100),
      child: Material(
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
                // Первая строка: Имя + теги справа
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
                                    ?.copyWith(
                                  fontSize: 10,
                                  color: _tagTextColor(tag),
                                ),
                              ),
                              backgroundColor: _tagColor(tag),
                              visualDensity: const VisualDensity(
                                  horizontal: -4, vertical: -4),
                              materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 0),
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
                // Телефон
                Text(
                  widget.contact.phone,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                // Статус под телефоном (компактный чип)
                Chip(
                  label: Text(
                    widget.contact.status,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontSize: 10, color: Colors.white),
                  ),
                  backgroundColor: _statusColor(widget.contact.status),
                  visualDensity:
                  const VisualDensity(horizontal: -4, vertical: -4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ],
            ),
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

/// Контент SnackBar с обратным отсчётом и прогресс-баром,
/// синхронизированным с duration самого SnackBar.
class _UndoSnackContent extends StatelessWidget {
  final Duration duration;
  const _UndoSnackContent({required this.duration});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: 0.0),
      duration: duration,
      builder: (context, value, _) {
        final secondsLeft =
        ((value * duration.inMilliseconds) / 1000).ceil().clamp(0, 999);
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
      },
    );
  }
}

enum SortOption { nameAsc, nameDesc, dateAsc, dateDesc }
