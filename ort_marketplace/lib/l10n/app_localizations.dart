// GENERATED CODE - DO NOT MODIFY BY HAND
// This file is generated from the .arb translation files in lib/l10n/.
// Run `flutter gen-l10n` (or `flutter pub get` with generate:true in pubspec)
// to regenerate.
//
// ignore_for_file: type=lint

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_sw.dart';

/// Callers can lookup localizations with an instance of [AppLocalizations]
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
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('ar'),
    Locale('sw'),
  ];

  String get appTitle;
  String get navHome;
  String get navSearch;
  String get navSaved;
  String get navMessages;
  String get navProfile;
  String get login;
  String get logout;
  String get register;
  String get email;
  String get password;
  String get confirmPassword;
  String get fullName;
  String get settings;
  String get appearance;
  String get theme;
  String get language;
  String get chooseLanguage;
  String get marketplace;
  String get marketplaceMode;
  String get modeLocal;
  String get modeInternational;
  String get distanceAndUnits;
  String get distanceUnit;
  String get autoDetectUnit;
  String get autoDetectUnitSubtitle;
  String get notifications;
  String get newMessages;
  String get orderUpdates;
  String get reviews;
  String get savedItemUpdates;
  String get privacy;
  String get privateProfile;
  String get privateProfileSubtitle;
  String get showEmail;
  String get showEmailSubtitle;
  String get account;
  String get changePassword;
  String get currentPassword;
  String get newPassword;
  String get updatePassword;
  String get properties;
  String get agriculture;
  String get manufacturing;
  String get search;
  String get searchHint;
  String get recentListings;
  String get featuredListings;
  String get viewAll;
  String get price;
  String get location;
  String get description;
  String get contactSeller;
  String get save;
  String get cancel;
  String get submit;
  String get loading;
  String get error;
  String get noResults;
  String get aiAssistant;
  String get wallet;
  String get orders;
  String get tracking;
  String get chooseTheme;
  String get chooseMarketplaceMode;
  String get chooseDistanceUnit;
  String get detectingLocation;
  String distanceUnitSetTo(String unit);
  String get passwordUpdated;
  String get fillAllPasswordFields;
  String get passwordsDoNotMatch;
  String get passwordTooShort;
  String get systemDefault;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => ['ar', 'en', 'sw'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  switch (locale.languageCode) {
    case 'ar': return AppLocalizationsAr();
    case 'sw': return AppLocalizationsSw();
    case 'en': return AppLocalizationsEn();
  }
  throw FlutterError('AppLocalizations.delegate failed to load unsupported locale "$locale".');
}
