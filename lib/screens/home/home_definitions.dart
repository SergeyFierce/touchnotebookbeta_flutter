part of home_screen;

/// ---------------------
/// Строки (русская локаль)
/// ---------------------
abstract class R {
  static const appTitle = 'Touch NoteBook';
  static const homeTitle = 'Главный экран';
  static const settings = 'Настройки';
  static const support = 'Поддержка';
  static const addContact = 'Добавить контакт';
  static const contactSaved = 'Контакт сохранён';
  static const noContacts = 'Пока нет контактов';
  static const noData = 'Нет данных';
  static const loadError = 'Не удалось загрузить данные';
  static const tryAgain = 'Повторить';
  static const checkNetwork = 'Проверьте подключение к сети и попробуйте ещё раз.';
  static const telegramNotInstalled = 'Telegram не установлен, откроем в браузере';
  static const telegramOpenFailed = 'Не удалось открыть Telegram';
  static const loading = 'Загрузка…';
  static const unknown = 'Неизвестно';
  static const qtyLabel = 'Количество';
  static const summaryTitle = 'Сводка по контактам';
  static const summaryKnownLabel = 'Всего известных контактов';
  static const summaryAllKnown = 'Все категории синхронизированы';
  static const quickActions = 'Быстрые действия';
  static const linkCopied = 'Ссылка скопирована';
  static const emptyStateHelp =
      'Создайте первый контакт. Ниже можно открыть списки по категориям.';
  static const chipHintOpenList = 'Откройте список по категории';
  static const dataUpdated = 'Данные обновлены';

  static String summaryUnknown(int count) {
    if (count <= 0) return summaryAllKnown;
    final noun = (count == 1) ? 'категории' : 'категориям';
    return 'По $count\u00A0$noun пока нет данных';
  }
}

/// ---------------------
/// Константы оформления
/// ---------------------
const kPad16 = EdgeInsets.all(16);
const kGap6 = SizedBox(height: 6);
const kGap8 = SizedBox(height: 8);
const kGap12 = SizedBox(height: 12);
const kGap16w = SizedBox(width: 16);
const kDurTap = Duration(milliseconds: 120);
const kDurFast = Duration(milliseconds: 200);
const kBr16 = BorderRadius.all(Radius.circular(16));

EdgeInsets homeListPadding(BuildContext context) {
  // SafeArea уже обрабатывает системные отступы снизу.
  const fabEstimatedHeight = 56.0; // высота FAB.extended
  const bottom = 16 + kFloatingActionButtonMargin + fabEstimatedHeight;
  return const EdgeInsets.fromLTRB(16, 16, 16, bottom);
}

/// Кешированный форматтер чисел для RU
final NumberFormat homeNumberFormat = NumberFormat.decimalPattern('ru');

/// ---------------------
/// Типобезопасные категории
/// ---------------------
enum ContactCategory { partner, client, prospect }

extension ContactCategoryX on ContactCategory {
  String get dbKey => switch (this) {
        ContactCategory.partner => 'Партнёр',
        ContactCategory.client => 'Клиент',
        ContactCategory.prospect => 'Потенциальный',
      };

  String get titlePlural => switch (this) {
        ContactCategory.partner => 'Партнёры',
        ContactCategory.client => 'Клиенты',
        ContactCategory.prospect => 'Потенциальные клиенты',
      };

  IconData get icon => switch (this) {
        ContactCategory.partner => Icons.handshake,
        ContactCategory.client => Icons.people,
        ContactCategory.prospect => Icons.person_add_alt_1,
      };

  /// Склонение + неразрывный пробел
  String russianCount(int count) {
    if (count == 0) {
      return switch (this) {
        ContactCategory.partner => 'Нет партнёров',
        ContactCategory.client => 'Нет клиентов',
        ContactCategory.prospect => 'Нет потенциальных клиентов',
      };
    }
    final m10 = count % 10;
    final m100 = count % 100;

    String pick({required String one, required String few, required String many}) {
      final word = (m10 == 1 && m100 != 11)
          ? one
          : (m10 >= 2 && m10 <= 4 && (m100 < 10 || m100 >= 20))
              ? few
              : many;
      return '${homeNumberFormat.format(count)}\u00A0$word';
    }

    return switch (this) {
      ContactCategory.partner =>
          pick(one: 'партнёр', few: 'партнёра', many: 'партнёров'),
      ContactCategory.client =>
          pick(one: 'клиент', few: 'клиента', many: 'клиентов'),
      ContactCategory.prospect => pick(
          one: 'потенциальный клиент',
          few: 'потенциальных клиента',
          many: 'потенциальных клиентов',
        ),
    };
  }
}

/// ---------------------
/// Типобезопасные счётчики
/// ---------------------
class Counts {
  final Map<ContactCategory, int> _values;

  const Counts(this._values);

  const Counts.zero()
      : _values = const {
          ContactCategory.partner: 0,
          ContactCategory.client: 0,
          ContactCategory.prospect: 0,
        };

  int of(ContactCategory c) => _values[c] ?? 0;

  bool get allZero => ContactCategory.values.every((c) => of(c) == 0);

  int get knownTotal {
    return ContactCategory.values.fold<int>(0, (sum, c) {
      final value = of(c);
      return value >= 0 ? sum + value : sum;
    });
  }

  int get unknownCount =>
      ContactCategory.values.where((c) => of(c) < 0).length;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Counts) return false;
    for (final c in ContactCategory.values) {
      if (of(c) != other.of(c)) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(ContactCategory.values.map(of));
}

/// Определяем количество колонок для адаптива
int calcColumns(BoxConstraints constraints) {
  final width = constraints.maxWidth;
  if (width >= 1200) return 3;
  if (width >= 800) return 2;
  return 1;
}

double gridChildAspectRatio(
  BoxConstraints constraints,
  int cols,
  EdgeInsets listPadding,
) {
  final horizontalPadding = listPadding.left + listPadding.right;
  const spacing = 12.0;
  final totalSpacing = horizontalPadding + spacing * (cols - 1);
  final availableWidth = constraints.maxWidth - totalSpacing;
  final cellWidth = availableWidth <= 0 ? 1.0 : availableWidth / cols;
  final viewportHeight = constraints.maxHeight;
  final baseHeight = cellWidth / 1.9; // умеренно широкие карточки
  const minHeight = 140.0;
  final fallbackMaxHeight = cellWidth * 1.1;
  final maxHeight = viewportHeight.isFinite
      ? math.max(minHeight, viewportHeight * 0.6)
      : fallbackMaxHeight;
  final cellHeight = baseHeight.clamp(minHeight, maxHeight).toDouble();
  return cellWidth / cellHeight;
}
