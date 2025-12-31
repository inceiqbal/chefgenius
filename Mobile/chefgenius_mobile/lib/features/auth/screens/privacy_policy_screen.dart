import 'package:flutter/material.dart';

import '../../../app/data/localization/app_strings_id.dart';
import '../../../app/data/localization/app_strings_en.dart';
import 'package:url_launcher/url_launcher.dart';


class PrivacyPolicyScreen extends StatelessWidget {
  static const String routeName = '/privacy-policy';

  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bodyStyle = textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface);
    Locale locale = Localizations.localeOf(context);
    Map<String, String> texts = locale.languageCode == 'en'
        ? englishTexts
        : indonesianTexts;

    return Scaffold(
      appBar: AppBar(
        title: Text(texts['privacy_screen_title'] ?? 'Kebijakan Privasi'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              texts['privacy_content'] ?? '',
              style: bodyStyle,
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(texts['privacy_contact_instagram_label'] ?? '• Instagram: '),
                InkWell(
                  child: Text(
                    texts['privacy_contact_instagram_value'] ?? '@inceiqbal',
                    style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                  ),
                  onTap: () async {
                    final url = texts['privacy_contact_instagram_url'] ?? 'https://instagram.com/inceiqbal';
                    if (await canLaunch(url)) {
                      await launch(url);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(texts['privacy_contact_whatsapp_label'] ?? '• WhatsApp: '),
                InkWell(
                  child: Text(
                    texts['privacy_contact_whatsapp_value'] ?? '087845245720',
                    style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                  ),
                  onTap: () async {
                    final url = texts['privacy_contact_whatsapp_url'] ?? 'https://wa.me/6287845245720';
                    if (await canLaunch(url)) {
                      await launch(url);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              texts['privacy_content_agree'] ?? '',
              style: bodyStyle,
            ),
          ],
        ),
      ),
    );
  }
}