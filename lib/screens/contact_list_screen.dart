import 'dart:async';

import 'package:flutter/material.dart';

import '../models/contact.dart';
import 'add_contact_screen.dart';

class ContactListScreen extends StatefulWidget {
  final String category;

  const ContactListScreen({super.key, required this.category});

  @override
  State<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends State<ContactListScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  SortOption _sort = SortOption.nameAsc;
  Set<String> _statusFilters = {};

  final List<Contact> _all = [
    Contact(
      name: 'Иван Петров',
      status: 'Активный',
      tags: ['Новый'],
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Contact(
      name: 'Сергей Иванов',
      status: 'Пассивный',
      tags: ['VIP'],
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    Contact(
      name: 'Мария Сидорова',
      status: 'Холодный',
      tags: ['Напомнить'],
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

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
        title: Text(widget.category),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemBuilder: (context, index) {
                      final c = contacts[index];
                      return _ContactCard(contact: c);
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemCount: contacts.length,
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddContactScreen(category: widget.category),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
    );
  }
}

class _ContactCard extends StatefulWidget {
  final Contact contact;
  const _ContactCard({required this.contact});

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
        color: Theme.of(context).colorScheme.surface,
        child: InkWell(
          borderRadius: border,
          onTap: () {},
          onTapDown: (_) => _set(true),
          onTapCancel: () => _set(false),
          onTapUp: (_) => _set(false),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.contact.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Chip(
                  label: Text(widget.contact.status),
                  backgroundColor: _statusColor(widget.contact.status),
                  labelStyle: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: -8,
                  children: [
                    for (final tag in widget.contact.tags)
                      Chip(
                        label: Text(tag),
                        backgroundColor: _tagColor(tag),
                        labelStyle: TextStyle(color: _tagTextColor(tag)),
                      ),
                  ],
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

enum SortOption { nameAsc, nameDesc, dateAsc, dateDesc }
