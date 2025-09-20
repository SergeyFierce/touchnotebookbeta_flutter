import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../strings.dart';

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

  Future<List<int>> _loadCounts() async {
    final categories = _categories();
    return Future.wait<int>(
      categories.map(
        (c) => ContactDatabase.instance.countByCategory(c.value),
      ),
    );
  }

  Future<void> _refresh() async {
    setState(() {});
  }

  Future<void> _openSupport(BuildContext context) async {
    const group = 'touchnotebook';
    final tgUri = Uri.parse('tg://resolve?domain=$group');
    final webUri = Uri.parse('https://t.me/$group');
    try {
      if (await canLaunchUrl(tgUri)) {
        await launchUrl(tgUri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(Strings.telegramNotInstalled)),
        );
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Strings.cannotOpenLink(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final categories = _categories();

    return Scaffold(
      appBar: AppBar(
        title: const Text(Strings.appTitle),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(color: colorScheme.primary),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: colorScheme.onPrimary,
                      child: Icon(
                        Icons.menu_book,
                        size: 36,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      Strings.appTitle,
                      style: const TextStyle(fontSize: 20, color: Colors.white),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home),
                title: const Text(Strings.drawerMain),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text(Strings.drawerSettings),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.support_agent),
                title: const Text(Strings.drawerSupport),
                onTap: () {
                  Navigator.pop(context);
                  _openSupport(context);
                },
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: ValueListenableBuilder<int>(
          valueListenable: ContactDatabase.instance.revision,
          builder: (context, _rev, _) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<int>>(
                key: ValueKey(_rev),
                future: _loadCounts(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    debugPrint('Error loading contact counts: ${snapshot.error}\n${snapshot.stackTrace}');
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text(Strings.dataLoadFailed)),
                      );
                    });
                    return const Center(child: Text(Strings.dataLoadError));
                  }

                        const SnackBar(content: Text(Strings.dataLoadFailed)),
                      );
                    });
                    return const Center(child: Text(Strings.dataLoadError));
                  }
                  final isLoading = snapshot.connectionState == ConnectionState.waiting;
                  final counts = snapshot.data ?? const [0, 0, 0];

                  return Scrollbar(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: categories.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final count = isLoading ? null : counts[index];
                        final subtitle =
                            count == null ? Strings.ellipsis : cat.plural(count);

                        return _CategoryCard(
                          category: cat,
                          subtitle: subtitle,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ContactListScreen(
                                  category: cat.value,
                                  title: cat.title,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: Strings.addContact,
        onPressed: () async {
          final saved = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddContactScreen()),
          );
          if (saved == true && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text(Strings.contactSaved)),
            );
          }
        },
        label: const Text(Strings.addContact),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _Category {
  final IconData icon;
  final String title;
  final String value;
  final String Function(int) plural;

  const _Category({
    required this.icon,
    required this.title,
    required this.value,
    required this.plural,
  });
}

List<_Category> _categories() => [
      _Category(
        icon: Icons.handshake,
        title: Strings.partnersTitle,
        value: 'Партнёр',
        plural: Strings.partnersCount,
      ),
      _Category(
        icon: Icons.people,
        title: Strings.clientsTitle,
        value: 'Клиент',
        plural: Strings.clientsCount,
      ),
      _Category(
        icon: Icons.person_add_alt_1,
        title: Strings.potentialTitle,
        value: 'Потенциальный',
        plural: Strings.potentialCount,
      ),
    ];

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
    final borderRadius = BorderRadius.circular(16);
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: widget.category.title,
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Material(
          color: colorScheme.surfaceVariant,
          elevation: 1.5,
          borderRadius: borderRadius,
          clipBehavior: Clip.antiAlias,
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
                  Hero(
                    tag: 'cat:${widget.category.value}',
                    flightShuttleBuilder: (_, __, ___, ____, _____) => Icon(
                      widget.category.icon, size: 32, color: colorScheme.primary,
                    ),
                    child: Icon(widget.category.icon, size: 32, color: colorScheme.primary),
                  ),
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
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, anim) =>
                              FadeTransition(opacity: anim, child: child),
                          child: Text(
                            widget.subtitle,
                            key: ValueKey(widget.subtitle),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
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
  }
}
