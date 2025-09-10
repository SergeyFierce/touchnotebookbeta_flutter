import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const List<Locale> supportedLocales = [Locale('ru')];

  String get appTitle => 'Touch NoteBook';
  String get drawerMain => 'Главный экран';
  String get drawerSettings => 'Настройки';
  String get drawerSupport => 'Поддержка';
  String get telegramNotInstalled => 'Telegram не установлен, открываем в браузере';
  String cannotOpenLink(String error) => 'Не удалось открыть ссылку: $error';
  String get dataLoadFailed => 'Не удалось загрузить данные';
  String get dataLoadError => 'Ошибка загрузки данных';
  String get contactSaved => 'Контакт сохранён';
  String get addContact => 'Добавить контакт';
  String get partnersTitle => 'Партнёры';
  String get partnersValue => 'Партнёр';
  String partnersCount(int count) => Intl.plural(
        count,
        one: '$count партнёр',
        few: '$count партнёра',
        many: '$count партнёров',
        other: '$count партнёра',
      );
  String get clientsTitle => 'Клиенты';
  String get clientsValue => 'Клиент';
  String clientsCount(int count) => Intl.plural(
        count,
        one: '$count клиент',
        few: '$count клиента',
        many: '$count клиентов',
        other: '$count клиента',
      );
  String get potentialTitle => 'Потенциальные';
  String get potentialValue => 'Потенциальный';
  String potentialCount(int count) => Intl.plural(
        count,
        one: '$count потенциальный',
        few: '$count потенциальных',
        many: '$count потенциальных',
        other: '$count потенциальных',
      );
  String get ellipsis => '…';
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ru';

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
