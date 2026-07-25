import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppLanguage {
  final String code;
  final String nativeName;
  final String englishName;

  const AppLanguage({
    required this.code,
    required this.nativeName,
    required this.englishName,
  });
}

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static const supportedLocales = [
    Locale('en'),
    Locale('ar'),
    Locale('es'),
    Locale('fr'),
  ];

  static const languages = [
    AppLanguage(code: 'en', nativeName: 'English', englishName: 'English'),
    AppLanguage(code: 'ar', nativeName: 'العربية', englishName: 'Arabic'),
    AppLanguage(code: 'es', nativeName: 'Español', englishName: 'Spanish'),
    AppLanguage(code: 'fr', nativeName: 'Français', englishName: 'French'),
  ];

  static AppLocalizations of(BuildContext context) {
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(l10n != null, 'AppLocalizations not found in context');
    return l10n!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  String _t(Map<String, String> values) => values[locale.languageCode] ?? values['en']!;

  String get appTitle => _t({
        'en': 'VitalFitness',
        'ar': 'فايتال فيتنس',
        'es': 'VitalFitness',
        'fr': 'VitalFitness',
      });

  // Navigation
  String get home => _t({'en': 'Home', 'ar': 'الرئيسية', 'es': 'Inicio', 'fr': 'Accueil'});
  String get schedule => _t({'en': 'Schedule', 'ar': 'الجدول', 'es': 'Horario', 'fr': 'Planning'});
  String get dietPlan => _t({'en': 'Diet Plan', 'ar': 'خطة النظام الغذائي', 'es': 'Plan de dieta', 'fr': 'Plan alimentaire'});
  String get classes => _t({'en': 'Classes', 'ar': 'الحصص', 'es': 'Clases', 'fr': 'Cours'});
  String get progress => _t({'en': 'Progress', 'ar': 'التقدم', 'es': 'Progreso', 'fr': 'Progrès'});
  String get coaches => _t({'en': 'Coaches', 'ar': 'المدربون', 'es': 'Entrenadores', 'fr': 'Coachs'});
  String get myCoach => _t({'en': 'My Coach', 'ar': 'مدربي', 'es': 'Mi entrenador', 'fr': 'Mon coach'});
  String get settings => _t({'en': 'Settings', 'ar': 'الإعدادات', 'es': 'Ajustes', 'fr': 'Paramètres'});
  String get clients => _t({'en': 'Clients', 'ar': 'العملاء', 'es': 'Clientes', 'fr': 'Clients'});
  String get messages => _t({'en': 'Messages', 'ar': 'الرسائل', 'es': 'Mensajes', 'fr': 'Messages'});

  // Settings
  String get settingsAndProfile => _t({
        'en': 'Settings & Profile',
        'ar': 'الإعدادات والملف الشخصي',
        'es': 'Ajustes y perfil',
        'fr': 'Paramètres et profil',
      });
  String get appSettings => _t({'en': 'App Settings', 'ar': 'إعدادات التطبيق', 'es': 'Ajustes de la app', 'fr': "Paramètres de l'app"});
  String get darkMode => _t({'en': 'Dark Mode', 'ar': 'الوضع الداكن', 'es': 'Modo oscuro', 'fr': 'Mode sombre'});
  String get language => _t({'en': 'Language', 'ar': 'اللغة', 'es': 'Idioma', 'fr': 'Langue'});
  String get chooseLanguage => _t({
        'en': 'Choose Language',
        'ar': 'اختر اللغة',
        'es': 'Elegir idioma',
        'fr': 'Choisir la langue',
      });
  String get languageUpdated => _t({
        'en': 'Language updated',
        'ar': 'تم تحديث اللغة',
        'es': 'Idioma actualizado',
        'fr': 'Langue mise à jour',
      });
  String get notifications => _t({'en': 'Notifications', 'ar': 'الإشعارات', 'es': 'Notificaciones', 'fr': 'Notifications'});
  String get workoutReminders => _t({
        'en': 'Workout Reminders',
        'ar': 'تذكيرات التمرين',
        'es': 'Recordatorios de entreno',
        'fr': "Rappels d'entraînement",
      });
  String get classUpdates => _t({
        'en': 'Class Updates',
        'ar': 'تحديثات الحصص',
        'es': 'Actualizaciones de clases',
        'fr': 'Mises à jour des cours',
      });
  String get coachMessages => _t({
        'en': 'Coach Messages',
        'ar': 'رسائل المدرب',
        'es': 'Mensajes del entrenador',
        'fr': 'Messages du coach',
      });
  String get personalInformation => _t({
        'en': 'Personal Information',
        'ar': 'المعلومات الشخصية',
        'es': 'Información personal',
        'fr': 'Informations personnelles',
      });
  String get personalInformationSubtitle => _t({
        'en': 'Used to tailor workouts and track your progress',
        'ar': 'تُستخدم لتخصيص التمارين ومتابعة تقدمك',
        'es': 'Para personalizar entrenamientos y seguir tu progreso',
        'fr': 'Pour adapter les entraînements et suivre vos progrès',
      });
  String get years => _t({'en': 'yrs', 'ar': 'سنة', 'es': 'años', 'fr': 'ans'});
  String get bmi => _t({'en': 'BMI', 'ar': 'مؤشر كتلة الجسم', 'es': 'IMC', 'fr': 'IMC'});
  String get fitnessGoals => _t({
        'en': 'Fitness Goals',
        'ar': 'أهداف اللياقة',
        'es': 'Objetivos fitness',
        'fr': 'Objectifs fitness',
      });
  String get saveProfileChanges => _t({
        'en': 'Save Profile Changes',
        'ar': 'حفظ تغييرات الملف',
        'es': 'Guardar cambios del perfil',
        'fr': 'Enregistrer le profil',
      });
  String get signOut => _t({'en': 'Sign Out', 'ar': 'تسجيل الخروج', 'es': 'Cerrar sesión', 'fr': 'Se déconnecter'});
  String get profileUpdated => _t({
        'en': 'Profile updated!',
        'ar': 'تم تحديث الملف الشخصي!',
        'es': '¡Perfil actualizado!',
        'fr': 'Profil mis à jour !',
      });
  String get preferences => _t({'en': 'PREFERENCES', 'ar': 'التفضيلات', 'es': 'PREFERENCIAS', 'fr': 'PRÉFÉRENCES'});
  String get account => _t({'en': 'ACCOUNT', 'ar': 'الحساب', 'es': 'CUENTA', 'fr': 'COMPTE'});
  String get pushNotifications => _t({
        'en': 'Push Notifications',
        'ar': 'الإشعارات الفورية',
        'es': 'Notificaciones push',
        'fr': 'Notifications push',
      });
  String get pushNotificationsSubtitle => _t({
        'en': 'Session reminders and client alerts',
        'ar': 'تذكيرات الجلسات وتنبيهات العملاء',
        'es': 'Recordatorios de sesión y alertas',
        'fr': 'Rappels de séance et alertes clients',
      });
  String get useDarkTheme => _t({
        'en': 'Use dark theme across the app',
        'ar': 'استخدم السمة الداكنة في التطبيق',
        'es': 'Usar tema oscuro en toda la app',
        'fr': "Utiliser le thème sombre dans l'app",
      });

  String languageLabel(String code) {
    return languages.firstWhere(
      (lang) => lang.code == code,
      orElse: () => languages.first,
    ).nativeName;
  }

  String get age => _t({'en': 'Age', 'ar': 'العمر', 'es': 'Edad', 'fr': 'Âge'});
  String get heightCm => _t({'en': 'Height (cm)', 'ar': 'الطول (سم)', 'es': 'Altura (cm)', 'fr': 'Taille (cm)'});
  String get weightKg => _t({'en': 'Weight (kg)', 'ar': 'الوزن (كغ)', 'es': 'Peso (kg)', 'fr': 'Poids (kg)'});
  String get cancel => _t({'en': 'Cancel', 'ar': 'إلغاء', 'es': 'Cancelar', 'fr': 'Annuler'});
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture(AppLocalizations(locale));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}
