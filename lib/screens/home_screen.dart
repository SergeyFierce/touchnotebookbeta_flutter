import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';

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
  late Future<List<int>> _countsFuture;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    ContactDatabase.instance.revision.addListener(_refresh);
  }

  @override
  void dispose() {
    ContactDatabase.instance.revision.removeListener(_refresh);
    super.dispose();
  }

  Future<List<int>> _loadCounts() async {
    final l10n = AppLocalizations.of(context)!;
    final categories = _categories(l10n);
    return Future.wait<int>(
      categories.map(
        (c) => ContactDatabase.instance.countByCategory(c.value),
      ),
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _countsFuture = _loadCounts();
    });
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
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.telegramNotInstalled)),
        );
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.cannotOpenLink(e.toString()))),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _countsFuture = _loadCounts();
      _initialized = true;
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
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final categories = _categories(l10n);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
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
                      l10n.appTitle,
                      style: const TextStyle(fontSize: 20, color: Colors.white),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home),
                title: Text(l10n.drawerMain),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: Text(l10n.drawerSettings),
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
                title: Text(l10n.drawerSupport),
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
            final future = _countsFuture;
            return RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<int>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    debugPrint('Error loading contact counts: ${snapshot.error}\n${snapshot.stackTrace}');
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.dataLoadFailed)),
                      );
                    });
                    return Center(child: Text(l10n.dataLoadError));
                  }
                  final isLoading = snapshot.connectionState == ConnectionState.waiting;
                  final counts = snapshot.data ?? const [0, 0, 0];

                  return Scrollbar(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                      itemCount: categories.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final count = isLoading ? null : counts[index];
                        final subtitle = count == null
                            ? l10n.ellipsis
                            : '$count ${_plural(count, cat.forms)}';

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
        onPressed: () async {
          final saved = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddContactScreen()),
          );
          if (saved == true && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.contactSaved)),
            );
          }
        },
        label: Text(l10n.addContact),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _Category {
  final IconData icon;
  final String title;
  final String value;
  final List<String> forms;

  const _Category({
    required this.icon,
    required this.title,
    required this.value,
    required this.forms,
  });
}

List<_Category> _categories(AppLocalizations l10n) => [
      _Category(
        icon: Icons.handshake,
        title: l10n.partnersTitle,
        value: l10n.partnersValue,
        forms: [l10n.partnersFormOne, l10n.partnersFormFew, l10n.partnersFormMany],
      ),
      _Category(
        icon: Icons.people,
        title: l10n.clientsTitle,
        value: l10n.clientsValue,
        forms: [l10n.clientsFormOne, l10n.clientsFormFew, l10n.clientsFormMany],
      ),
      _Category(
        icon: Icons.person_add_alt_1,
        title: l10n.potentialTitle,
        value: l10n.potentialValue,
        forms: [l10n.potentialFormOne, l10n.potentialFormFew, l10n.potentialFormMany],
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
