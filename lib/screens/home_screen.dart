library home_screen;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/contact_database.dart';
import '../widgets/system_notifications.dart';
import 'add_contact_screen.dart';
import 'contact_list_screen.dart';
import 'settings_screen.dart';

part 'home/home_definitions.dart';
part 'home/home_controller.dart';
part 'home/home_actions.dart';
part 'home/home_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RestorationMixin {
  late final HomeStateController _controller;
  late Future<Counts> _countsFuture;
  late final VoidCallback _removeRevisionListener;
  final RestorableInt _drawerIndex = RestorableInt(0);
  final HomeActions _actions = const HomeActions();
  bool _loadErrorShown = false;

  @override
  String? get restorationId => 'home_screen';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_drawerIndex, 'home_drawer_index');
  }

  @override
  void initState() {
    super.initState();
    _controller = HomeStateController();
    _countsFuture = _controller.loadCounts();
    _removeRevisionListener =
        _controller.listenForRevisionUpdates(_triggerRefreshCounts);
  }

  @override
  void dispose() {
    _removeRevisionListener();
    _controller.dispose();
    _drawerIndex.dispose();
    super.dispose();
  }

  void _triggerRefreshCounts() {
    if (!mounted) return;
    setState(() {
      _countsFuture = _controller.loadCounts();
    });
  }

  Future<void> _refresh() async {
    _triggerRefreshCounts();
  }

  void _showLoadErrorOnce(BuildContext context) {
    if (_loadErrorShown) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showErrorBanner(R.loadError);
    });
    _loadErrorShown = true;
  }

  Future<void> _openSupport() => _actions.openSupport(context);

  Future<void> _openAddContact() => _actions.openAddContact(context);

  void _openSettings() => _actions.openSettings(context);

  void _openCategory(ContactCategory category) =>
      _actions.openCategoryList(context, category);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      restorationId: 'home_scaffold',
      appBar: AppBar(title: const Text(R.homeTitle)),
      drawer: NavigationDrawer(
        selectedIndex: _drawerIndex.value,
        onDestinationSelected: (index) {
          _drawerIndex.value = index;
          Navigator.pop(context);
          switch (index) {
            case 1:
              _openSettings();
              break;
            case 2:
              _openSupport();
              break;
            default:
              break;
          }
        },
        children: const [
          NavigationDrawerDestination(
            icon: Icon(Icons.home),
            selectedIcon: Icon(Icons.home_filled),
            label: Text(R.homeTitle),
          ),
          NavigationDrawerDestination(
            icon: Icon(Icons.settings),
            selectedIcon: Icon(Icons.settings_suggest),
            label: Text(R.settings),
          ),
          NavigationDrawerDestination(
            icon: Icon(Icons.support_agent),
            selectedIcon: Icon(Icons.support),
            label: Text(R.support),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<Counts>(
            future: _countsFuture,
            builder: (context, snapshot) {
              final waiting =
                  snapshot.connectionState == ConnectionState.waiting;
              final hasSomeData =
                  snapshot.hasData || _controller.lastGoodCounts != null;

              final counts = _controller.effectiveCounts(snapshot);

              if (snapshot.hasError && !hasSomeData) {
                debugPrint(
                  'Error loading contact counts: ${snapshot.error}\n${snapshot.stackTrace}',
                );
                _showLoadErrorOnce(context);
                return ListView(
                  key: const PageStorageKey('home-error-list'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: homeListPadding(context),
                  children: const [
                    _ErrorCard(onRetry: null),
                  ],
                );
              }

              _loadErrorShown = false;

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !snapshot.hasData) return;
                final shouldNotify =
                    _controller.registerCounts(snapshot.data!);
                if (shouldNotify) {
                  showInfoBanner(
                    R.dataUpdated,
                    duration: const Duration(milliseconds: 1500),
                  );
                }
              });

              final isInitialLoad = !hasSomeData && waiting;

              if (isInitialLoad) {
                return ListView(
                  key: const PageStorageKey('home-initial-loading'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: homeListPadding(context),
                  children: const [
                    _SkeletonLine(widthFactor: 0.9),
                    SizedBox(height: 12),
                    _SkeletonLine(widthFactor: 0.85),
                    SizedBox(height: 12),
                    _SkeletonLine(widthFactor: 0.8),
                  ],
                );
              }

              final showSummary = !counts.allZero;
              final listPadding = homeListPadding(context);

              return LayoutBuilder(
                builder: (context, constraints) {
                  final cols = calcColumns(constraints);

                  final items = ContactCategory.values.map((cat) {
                    final c = counts.of(cat);
                    final subtitle =
                        (c < 0) ? R.unknown : cat.russianCount(c);
                    final chip =
                        (c < 0) ? '—' : homeNumberFormat.format(c);
                    return _CategoryCard(
                      category: cat,
                      subtitle: subtitle,
                      trailingCount: chip,
                      isLoading: false,
                      onTap: () => _openCategory(cat),
                    );
                  }).toList(growable: false);

                  if (cols == 1) {
                    return Scrollbar(
                      child: ListView.separated(
                        key: const PageStorageKey('home-list'),
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: listPadding,
                        itemCount: items.length + (showSummary ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, index) {
                          if (showSummary && index == 0) {
                            return _SummaryCard(
                              knownTotal: counts.knownTotal,
                              unknownCount: counts.unknownCount,
                            );
                          }
                          final itemIndex = showSummary ? index - 1 : index;
                          return items[itemIndex];
                        },
                      ),
                    );
                  }

                  return Scrollbar(
                    thumbVisibility: true,
                    child: CustomScrollView(
                      key: const PageStorageKey('home-grid'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        if (showSummary)
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              listPadding.left,
                              listPadding.top,
                              listPadding.right,
                              12,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: _SummaryCard(
                                knownTotal: counts.knownTotal,
                                unknownCount: counts.unknownCount,
                              ),
                            ),
                          ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            listPadding.left,
                            showSummary ? 0 : listPadding.top,
                            listPadding.right,
                            listPadding.bottom,
                          ),
                          sliver: SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => RepaintBoundary(child: items[i]),
                              childCount: items.length,
                            ),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cols,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: gridChildAspectRatio(
                                constraints,
                                cols,
                                listPadding,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: R.addContact,
        onPressed: _openAddContact,
        label: const Text(R.addContact),
        icon: const Icon(Icons.person_add),
      ),
    );
  }
}
