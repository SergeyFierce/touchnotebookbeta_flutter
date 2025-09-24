part of home_screen;

class HomeStateController {
  HomeStateController({
    ContactDatabase? database,
    Duration refreshDebounce = const Duration(milliseconds: 200),
  })  : _database = database ?? ContactDatabase.instance,
        _refreshDebounce = refreshDebounce;

  final ContactDatabase _database;
  final Duration _refreshDebounce;

  Timer? _debounce;
  Counts? _lastCountsShown;
  Counts? _lastGoodCounts;

  Counts? get lastGoodCounts => _lastGoodCounts;

  Future<int> _safe(Future<int> future) async {
    try {
      return await future.timeout(const Duration(seconds: 3));
    } catch (e, s) {
      debugPrint('count error: $e\n$s');
      return -1; // -1 = неизвестно
    }
  }

  Future<Counts> loadCounts() async {
    final partner = await _safe(
      _database.countByCategory(ContactCategory.partner.dbKey),
    );
    final client = await _safe(
      _database.countByCategory(ContactCategory.client.dbKey),
    );
    final prospect = await _safe(
      _database.countByCategory(ContactCategory.prospect.dbKey),
    );
    return Counts({
      ContactCategory.partner: partner,
      ContactCategory.client: client,
      ContactCategory.prospect: prospect,
    });
  }

  VoidCallback listenForRevisionUpdates(VoidCallback triggerRefresh) {
    void listener() => scheduleRefresh(triggerRefresh);
    _database.revision.addListener(listener);
    return () => _database.revision.removeListener(listener);
  }

  void scheduleRefresh(VoidCallback triggerRefresh) {
    _debounce?.cancel();
    _debounce = Timer(_refreshDebounce, triggerRefresh);
  }

  Counts effectiveCounts(AsyncSnapshot<Counts> snapshot) {
    return snapshot.data ?? _lastGoodCounts ?? const Counts.zero();
  }

  bool registerCounts(Counts newCounts) {
    final last = _lastCountsShown;
    _lastCountsShown = newCounts;
    if (newCounts.unknownCount == 0 || newCounts.knownTotal > 0) {
      _lastGoodCounts = newCounts;
    }
    if (last == null) {
      return false;
    }
    return last.unknownCount > 0 && newCounts.unknownCount < last.unknownCount;
  }

  void dispose() {
    _debounce?.cancel();
  }
}
