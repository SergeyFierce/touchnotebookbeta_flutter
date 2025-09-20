// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Touch NoteBook';

  @override
  String get drawerMain => 'Main Screen';

  @override
  String get drawerSettings => 'Settings';

  @override
  String get drawerSupport => 'Support';

  @override
  String get telegramNotInstalled =>
      'Telegram is not installed, opening in browser';

  @override
  String cannotOpenLink(String error) {
    return 'Could not open link: $error';
  }

  @override
  String get dataLoadFailed => 'Failed to load data';

  @override
  String get dataLoadError => 'Data load error';

  @override
  String get contactSaved => 'Contact saved';

  @override
  String get addContact => 'Add contact';

  @override
  String get partnersTitle => 'Partners';

  @override
  String partnersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count partners',
      one: '$count partner',
    );
    return '$_temp0';
  }

  @override
  String get clientsTitle => 'Clients';

  @override
  String clientsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clients',
      one: '$count client',
    );
    return '$_temp0';
  }

  @override
  String get potentialTitle => 'Potential';

  @override
  String potentialCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count potential',
      one: '$count potential',
    );
    return '$_temp0';
  }

  @override
  String get category => 'Category';

  @override
  String get ellipsis => '…';

  @override
  String get noteSaved => 'Note saved';

  @override
  String get deleteNoteQuestion => 'Delete note?';

  @override
  String get deleteNoteWarning => 'This action cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get undo => 'Undo';

  @override
  String get close => 'Close';

  @override
  String get note => 'Note';

  @override
  String get save => 'Save';

  @override
  String get text => 'Text';

  @override
  String get noteTextLabel => 'Note text*';

  @override
  String get enterText => 'Enter text';

  @override
  String get date => 'Date';

  @override
  String get dateAdded => 'Date added';

  @override
  String get deleteNote => 'Delete note';

  @override
  String get noteDeleted => 'Note deleted';

  @override
  String get secondsShort => 's';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageRussian => 'Russian';

  @override
  String get languageEnglish => 'English';
}
