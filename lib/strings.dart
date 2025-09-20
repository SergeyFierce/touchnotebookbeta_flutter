class Strings {
  static const appTitle = 'Touch NoteBook';
  static const drawerMain = 'Главный экран';
  static const drawerSettings = 'Настройки';
  static const drawerSupport = 'Поддержка';
  static const telegramNotInstalled =
      'Telegram не установлен, открываем в браузере';

  static String cannotOpenLink(String error) => 'Не удалось открыть ссылку: $error';

  static const dataLoadFailed = 'Не удалось загрузить данные';
  static const dataLoadError = 'Ошибка загрузки данных';

  static const contactSaved = 'Контакт сохранён';
  static const addContact = 'Добавить контакт';

  static const partnersTitle = 'Партнёры';
  static String partnersCount(int count) => _plural(
        count,
        one: '$count партнёр',
        few: '$count партнёра',
        many: '$count партнёров',
        other: '$count партнёра',
      );

  static const clientsTitle = 'Клиенты';
  static String clientsCount(int count) => _plural(
        count,
        one: '$count клиент',
        few: '$count клиента',
        many: '$count клиентов',
        other: '$count клиента',
      );

  static const potentialTitle = 'Потенциальные';
  static String potentialCount(int count) => _plural(
        count,
        one: '$count потенциальный',
        few: '$count потенциальных',
        many: '$count потенциальных',
        other: '$count потенциальных',
      );

  static const category = 'Категория';
  static const ellipsis = '…';

  static const noteSaved = 'Заметка сохранена';
  static const deleteNoteQuestion = 'Удалить заметку?';
  static const deleteNoteWarning = 'Это действие нельзя отменить.';
  static const cancel = 'Отмена';
  static const delete = 'Удалить';
  static const undo = 'Отменить';
  static const close = 'Закрыть';
  static const note = 'Заметка';
  static const save = 'Сохранить';
  static const text = 'Текст';
  static const noteTextLabel = 'Текст заметки*';
  static const enterText = 'Введите текст';
  static const date = 'Дата';
  static const dateAdded = 'Дата добавления';
  static const deleteNote = 'Удалить заметку';
  static const noteDeleted = 'Заметка удалена';
  static const secondsShort = 'с';

  static const settingsTitle = 'Настройки';

  static String _plural(
    int count, {
    required String one,
    required String few,
    required String many,
    required String other,
  }) {
    final absCount = count.abs();
    final mod10 = absCount % 10;
    final mod100 = absCount % 100;

    if (mod10 == 1 && mod100 != 11) {
      return one;
    }
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return few;
    }
    if (mod10 == 0 || (mod10 >= 5 && mod10 <= 9) || (mod100 >= 11 && mod100 <= 14)) {
      return many;
    }
    return other;
  }
}
