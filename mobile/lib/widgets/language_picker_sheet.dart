import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../screens/dashboard/widgets/coach_home/coach_dashboard_theme.dart';

Future<void> showLanguagePicker(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final current = Localizations.localeOf(context).languageCode;

  await showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.chooseLanguage,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...AppLocalizations.languages.map((lang) {
                return RadioListTile<String>(
                  value: lang.code,
                  groupValue: current,
                  activeColor: CoachDashboardTheme.primary,
                  title: Text(lang.nativeName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(lang.englishName),
                  onChanged: (code) async {
                    if (code == null || code == current) {
                      Navigator.pop(ctx);
                      return;
                    }
                    await MyApp.of(context)?.setLocale(Locale(code));
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.languageUpdated),
                          backgroundColor: CoachDashboardTheme.success,
                        ),
                      );
                    }
                  },
                );
              }),
            ],
          ),
        ),
      );
    },
  );
}
