// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Touch NoteBook';

  @override
  String get drawerMain => 'Главный экран';

  @override
  String get drawerSettings => 'Настройки';

  @override
  String get drawerSupport => 'Поддержка';

  @override
  String get telegramNotInstalled =>
      'Telegram не установлен, открываем в браузере';

  @override
  String cannotOpenLink(String error) {
    return 'Не удалось открыть ссылку: $error';
  }

  @override
  String get dataLoadFailed => 'Не удалось загрузить данные';

  @override
  String get dataLoadError => 'Ошибка загрузки данных';

  @override
  String get contactSaved => 'Контакт сохранён';

  @override
  String get addContact => 'Добавить контакт';

  @override
  String get partnersTitle => 'Партнёры';

  @override
  String partnersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count партнёра',
      many: '$count партнёров',
      few: '$count партнёра',
      one: '$count партнёр',
    );
    return '$_temp0';
  }

  @override
  String get clientsTitle => 'Клиенты';

  @override
  String clientsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count клиента',
      many: '$count клиентов',
      few: '$count клиента',
      one: '$count клиент',
    );
    return '$_temp0';
  }

  @override
  String get potentialTitle => 'Потенциальные';

  @override
  String potentialCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count потенциальных',
      many: '$count потенциальных',
      few: '$count потенциальных',
      one: '$count потенциальный',
    );
    return '$_temp0';
  }

  @override
  String get category => 'Категория';

  @override
  String get ellipsis => '…';

  @override
  String get noteSaved => 'Заметка сохранена';

  @override
  String get deleteNoteQuestion => 'Удалить заметку?';

  @override
  String get deleteNoteWarning => 'Это действие нельзя отменить.';

  @override
  String get cancel => 'Отмена';

  @override
  String get delete => 'Удалить';

  @override
  String get undo => 'Отменить';

  @override
  String get close => 'Закрыть';

  @override
  String get note => 'Заметка';

  @override
  String get save => 'Сохранить';

  @override
  String get text => 'Текст';

  @override
  String get noteTextLabel => 'Текст заметки*';

  @override
  String get enterText => 'Введите текст';

  @override
  String get date => 'Дата';

  @override
  String get dateAdded => 'Дата добавления';

  @override
  String get deleteNote => 'Удалить заметку';

  @override
  String get noteDeleted => 'Заметка удалена';

  @override
  String get secondsShort => 'с';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsLanguage => 'Язык';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageEnglish => 'Английский';
}
