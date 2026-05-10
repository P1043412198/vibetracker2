import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_be.dart';
import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ru'),
    Locale('be'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ru, this message translates to:
  /// **'Vibesight Tracker'**
  String get appTitle;

  /// No description provided for @navDashboard.
  ///
  /// In ru, this message translates to:
  /// **'Главная'**
  String get navDashboard;

  /// No description provided for @navFinance.
  ///
  /// In ru, this message translates to:
  /// **'Финансы'**
  String get navFinance;

  /// No description provided for @navTasks.
  ///
  /// In ru, this message translates to:
  /// **'Задачи'**
  String get navTasks;

  /// No description provided for @navHabits.
  ///
  /// In ru, this message translates to:
  /// **'Привычки'**
  String get navHabits;

  /// No description provided for @navMore.
  ///
  /// In ru, this message translates to:
  /// **'Ещё'**
  String get navMore;

  /// No description provided for @navInbox.
  ///
  /// In ru, this message translates to:
  /// **'Инбокс'**
  String get navInbox;

  /// No description provided for @navPomodoro.
  ///
  /// In ru, this message translates to:
  /// **'Pomodoro'**
  String get navPomodoro;

  /// No description provided for @navWater.
  ///
  /// In ru, this message translates to:
  /// **'Водный баланс'**
  String get navWater;

  /// No description provided for @navSleep.
  ///
  /// In ru, this message translates to:
  /// **'Сон'**
  String get navSleep;

  /// No description provided for @navSpheres.
  ///
  /// In ru, this message translates to:
  /// **'Сферы'**
  String get navSpheres;

  /// No description provided for @navGoals.
  ///
  /// In ru, this message translates to:
  /// **'Цели'**
  String get navGoals;

  /// No description provided for @navWorkouts.
  ///
  /// In ru, this message translates to:
  /// **'Тренировки'**
  String get navWorkouts;

  /// No description provided for @navHousehold.
  ///
  /// In ru, this message translates to:
  /// **'Хозяйство'**
  String get navHousehold;

  /// No description provided for @navShoppingList.
  ///
  /// In ru, this message translates to:
  /// **'Список покупок'**
  String get navShoppingList;

  /// No description provided for @navWorkSchedule.
  ///
  /// In ru, this message translates to:
  /// **'График работы'**
  String get navWorkSchedule;

  /// No description provided for @navAnalytics.
  ///
  /// In ru, this message translates to:
  /// **'Аналитика'**
  String get navAnalytics;

  /// No description provided for @navPasswords.
  ///
  /// In ru, this message translates to:
  /// **'Пароли'**
  String get navPasswords;

  /// No description provided for @navTools.
  ///
  /// In ru, this message translates to:
  /// **'Инструменты'**
  String get navTools;

  /// No description provided for @navSettings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get navSettings;

  /// No description provided for @settingsAppearance.
  ///
  /// In ru, this message translates to:
  /// **'Внешний вид'**
  String get settingsAppearance;

  /// No description provided for @settingsLanguage.
  ///
  /// In ru, this message translates to:
  /// **'Язык'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In ru, this message translates to:
  /// **'Системный'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageRu.
  ///
  /// In ru, this message translates to:
  /// **'Русский'**
  String get settingsLanguageRu;

  /// No description provided for @settingsLanguageBe.
  ///
  /// In ru, this message translates to:
  /// **'Беларуская'**
  String get settingsLanguageBe;

  /// No description provided for @settingsLanguageEn.
  ///
  /// In ru, this message translates to:
  /// **'English'**
  String get settingsLanguageEn;

  /// No description provided for @settingsThemeAuto.
  ///
  /// In ru, this message translates to:
  /// **'Авто'**
  String get settingsThemeAuto;

  /// No description provided for @settingsThemeLight.
  ///
  /// In ru, this message translates to:
  /// **'Светлая'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In ru, this message translates to:
  /// **'Тёмная'**
  String get settingsThemeDark;

  /// No description provided for @settingsSecurity.
  ///
  /// In ru, this message translates to:
  /// **'Безопасность'**
  String get settingsSecurity;

  /// No description provided for @settingsPinNotSet.
  ///
  /// In ru, this message translates to:
  /// **'PIN-код не задан'**
  String get settingsPinNotSet;

  /// No description provided for @settingsPinSet.
  ///
  /// In ru, this message translates to:
  /// **'PIN-код активен'**
  String get settingsPinSet;

  /// No description provided for @settingsConfigureDashboard.
  ///
  /// In ru, this message translates to:
  /// **'Настроить дашборд'**
  String get settingsConfigureDashboard;

  /// No description provided for @settingsFinance.
  ///
  /// In ru, this message translates to:
  /// **'Финансы'**
  String get settingsFinance;

  /// No description provided for @settingsDefaultCurrency.
  ///
  /// In ru, this message translates to:
  /// **'Валюта по умолчанию'**
  String get settingsDefaultCurrency;

  /// No description provided for @settingsAi.
  ///
  /// In ru, this message translates to:
  /// **'AI (Gemini)'**
  String get settingsAi;

  /// No description provided for @settingsData.
  ///
  /// In ru, this message translates to:
  /// **'Данные'**
  String get settingsData;

  /// No description provided for @settingsDeleteAll.
  ///
  /// In ru, this message translates to:
  /// **'Удалить все данные'**
  String get settingsDeleteAll;

  /// No description provided for @settingsDeleteAllSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Сбрасывает локальное хранилище. Действие необратимо.'**
  String get settingsDeleteAllSubtitle;

  /// No description provided for @commonCancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get commonDelete;

  /// No description provided for @commonSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get commonSave;

  /// No description provided for @pinEnter.
  ///
  /// In ru, this message translates to:
  /// **'Введите PIN-код'**
  String get pinEnter;

  /// No description provided for @pinSet.
  ///
  /// In ru, this message translates to:
  /// **'Задать PIN-код'**
  String get pinSet;

  /// No description provided for @pinChange.
  ///
  /// In ru, this message translates to:
  /// **'Сменить PIN-код'**
  String get pinChange;

  /// No description provided for @pinDisabled.
  ///
  /// In ru, this message translates to:
  /// **'PIN-код отключён'**
  String get pinDisabled;

  /// No description provided for @pinSaved.
  ///
  /// In ru, this message translates to:
  /// **'PIN-код сохранён'**
  String get pinSaved;

  /// No description provided for @pinDescription.
  ///
  /// In ru, this message translates to:
  /// **'Приложение заблокировано для защиты данных'**
  String get pinDescription;

  /// No description provided for @pinCurrent.
  ///
  /// In ru, this message translates to:
  /// **'Текущий PIN-код'**
  String get pinCurrent;

  /// No description provided for @pinNew.
  ///
  /// In ru, this message translates to:
  /// **'Новый PIN-код'**
  String get pinNew;

  /// No description provided for @pinRepeat.
  ///
  /// In ru, this message translates to:
  /// **'Повторите PIN-код'**
  String get pinRepeat;

  /// No description provided for @pinDisable.
  ///
  /// In ru, this message translates to:
  /// **'Отключить PIN'**
  String get pinDisable;

  /// No description provided for @pinSaveButton.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить PIN'**
  String get pinSaveButton;

  /// No description provided for @pinHelp.
  ///
  /// In ru, this message translates to:
  /// **'PIN запрашивается при запуске и при возврате из фона. Хранится локально в Hive — это приватная защита от случайного доступа.'**
  String get pinHelp;

  /// No description provided for @dashboardSettingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Настроить дашборд'**
  String get dashboardSettingsTitle;

  /// No description provided for @dashboardSettingsHint.
  ///
  /// In ru, this message translates to:
  /// **'Перетаскивай за иконку справа, чтобы изменить порядок. Переключатель скрывает виджет.'**
  String get dashboardSettingsHint;

  /// No description provided for @dashboardReset.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить'**
  String get dashboardReset;

  /// No description provided for @dashboardResetDone.
  ///
  /// In ru, this message translates to:
  /// **'Дашборд сброшен к умолчанию'**
  String get dashboardResetDone;

  /// No description provided for @dashboardEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Все виджеты скрыты'**
  String get dashboardEmpty;

  /// No description provided for @dashboardEmptyHint.
  ///
  /// In ru, this message translates to:
  /// **'Включи нужные виджеты в настройках дашборда'**
  String get dashboardEmptyHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['be', 'en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'be':
      return AppLocalizationsBe();
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
