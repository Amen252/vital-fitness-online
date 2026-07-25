import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'l10n/locale_service.dart';
import 'services/api_service.dart';
import 'models/user_model.dart';
import 'screens/auth/auth_home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LocaleService.init();
  final apiService = ApiService();
  await apiService.init();

  final User? initialUser = await apiService.getMe();

  runApp(MyApp(initialUser: initialUser));
}

class MyApp extends StatefulWidget {
  final User? initialUser;

  const MyApp({super.key, this.initialUser});

  static _MyAppState? of(BuildContext context) => context.findAncestorStateOfType<_MyAppState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDark = false;
  Locale _locale = LocaleService.locale;

  bool get isDark => _isDark;
  Locale get locale => _locale;

  void toggleTheme(bool isDark) {
    setState(() => _isDark = isDark);
  }

  Future<void> setLocale(Locale locale) async {
    await LocaleService.save(locale);
    setState(() => _locale = locale);
  }

  Widget _buildHome() => AuthHome(user: widget.initialUser);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VitalFitness',
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        brightness: _isDark ? Brightness.dark : Brightness.light,
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: _buildHome(),
    );
  }
}
