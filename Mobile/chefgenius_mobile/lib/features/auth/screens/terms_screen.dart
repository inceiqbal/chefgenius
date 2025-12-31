

import '../../../app/data/localization/app_strings_id.dart';
import '../../../app/data/localization/app_strings_en.dart';
import 'package:flutter/material.dart';


class TermsScreen extends StatelessWidget {
  // Ini rute yang kita daftarkan di routes.dart
  static const String routeName = '/terms';

  const TermsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Mengambil style tema default untuk teks
    final textTheme = Theme.of(context).textTheme;
    // Pastikan warna teks kontras dengan background
    final bodyStyle = textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface);

    // Ganti dengan cara manual: ambil locale, lalu ambil string dari map
    Locale locale = Localizations.localeOf(context);
    Map<String, String> texts = locale.languageCode == 'en'
        ? englishTexts
        : indonesianTexts;
    return Scaffold(
      appBar: AppBar(
        title: Text(texts['terms_screen_title'] ?? 'Syarat & Ketentuan'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: SelectableText(
          texts['terms_content'] ?? '',
          style: bodyStyle,
        ),
      ),
    );
  }
}