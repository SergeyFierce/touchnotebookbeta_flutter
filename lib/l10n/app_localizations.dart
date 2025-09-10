import 'package:flutter/widgets.dart';

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
  String get partnersFormOne => 'партнёр';
  String get partnersFormFew => 'партнёра';
  String get partnersFormMany => 'партнёров';
  String get clientsTitle => 'Клиенты';
  String get clientsValue => 'Клиент';
  String get clientsFormOne => 'клиент';
  String get clientsFormFew => 'клиента';
  String get clientsFormMany => 'клиентов';
  String get potentialTitle => 'Потенциальные';
  String get potentialValue => 'Потенциальный';
  String get potentialFormOne => 'потенциальный';
  String get potentialFormFew => 'потенциальных';
  String get potentialFormMany => 'потенциальных';
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
