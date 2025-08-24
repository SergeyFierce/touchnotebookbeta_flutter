import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'add_contact_screen.dart';
import 'settings_screen.dart';
import 'contact_list_screen.dart';
import '../services/contact_database.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  Future<void> _openSupport(BuildContext context) async {
    const group = 'touchnotebook';
    final tgUri = Uri.parse('tg://resolve?domain=$group');
    final webUri = Uri.parse('https://t.me/$group');
    if (await canLaunchUrl(tgUri)) {
      await launchUrl(tgUri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Telegram не установлен, открываем в браузере')),
      );
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  String _plural(int count, List<String> forms) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return forms[0];
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) {
      return forms[1];
    }
    return forms[2];
  }

  @override
  Widget build(BuildContext context) {
    final categories = const [
      _Category(
        icon: Icons.handshake,
        title: 'Партнёры',
        value: 'Партнёр',
        forms: ['партнёр', 'партнёра', 'партнёров'],
      ),
      _Category(
        icon: Icons.people,
        title: 'Клиенты',
        value: 'Клиент',
        forms: ['клиент', 'клиента', 'клиентов'],
      ),
      _Category(
        icon: Icons.person_add_alt_1,
        title: 'Потенциальные',
        value: 'Потенциальный',
        forms: ['потенциальный', 'потенциальных', 'потенциальных'],
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Touch NoteBook'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Theme.of(context).colorScheme.onPrimary,
                    child: Icon(
                      Icons.menu_book,
                      size: 36,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Touch NoteBook',
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Главный экран'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Настройки'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
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
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final cat = categories[index];
          return FutureBuilder<int>(
            future: ContactDatabase.instance.countByCategory(cat.value),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return _CategoryCard(
                category: cat,
                subtitle: '$count ${_plural(count, cat.forms)}',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ContactListScreen(
                        category: cat.value,
                        title: cat.title,
                      ),
                    ),
                  ).then((_) => setState(() {}));
                },
              );
            },
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemCount: categories.length,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddContactScreen(),
            ),
          );
          if (saved == true && mounted) {
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Контакт сохранён')),
            );
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Добавить контакт'),
      ),
    );
  }
}

class _Category {
  final IconData icon;
  final String title; // plural title
  final String value; // singular value for DB
  final List<String> forms;

  const _Category({
    required this.icon,
    required this.title,
    required this.value,
    required this.forms,
  });
}

class _CategoryCard extends StatefulWidget {
  final _Category category;
  final String subtitle;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.subtitle,
    required this.onTap,
  });

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
    final borderRadius = BorderRadius.circular(12);
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: borderRadius,
        elevation: 2,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: widget.onTap,
          onTapDown: (_) => _setPressed(true),
          onTapCancel: () => _setPressed(false),
          onTapUp: (_) => _setPressed(false),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(widget.category.icon, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.category.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(widget.subtitle,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
