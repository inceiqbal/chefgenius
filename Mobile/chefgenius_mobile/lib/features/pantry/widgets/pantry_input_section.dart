import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:provider/provider.dart'; // IMPORT PROVIDER
import '../../../../app/data/providers/language_provider.dart'; // IMPORT LANG PROVIDER

class PantryInputSection extends StatelessWidget {
  final GlobalKey showcaseKey;
  final TextEditingController controller;
  final bool isOffline;
  final bool isAdding;
  final VoidCallback onScan;
  final VoidCallback onAdd;

  const PantryInputSection({
    super.key,
    required this.showcaseKey,
    required this.controller,
    required this.isOffline,
    required this.isAdding,
    required this.onScan,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    // 1. PANGGIL PROVIDER BAHASA
    final lang = context.watch<LanguageProvider>();

    return Showcase(
      key: showcaseKey,
      title: lang.getText('pantry_step_1_title'), // Teks Dinamis
      description: lang.getText('pantry_step_1_desc'), // Teks Dinamis
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !isOffline,
                decoration: InputDecoration(
                  hintText: isOffline
                      ? lang.getText('pantry_hint_offline') // Teks Dinamis
                      : lang.getText('pantry_hint_online'), // Teks Dinamis
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.add),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.camera_alt_rounded, color: Colors.purple),
                    tooltip: lang.getText('pantry_cam_tooltip'), // Teks Dinamis
                    // Logika Cei Vision tetap dipanggil dari Parent
                    onPressed: isAdding || isOffline ? null : onScan,
                  ),
                ),
                onSubmitted: (_) => isAdding || isOffline ? null : onAdd(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: isAdding || isOffline ? null : onAdd,
              child: isAdding
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(lang.getText('add_btn')), // Teks Dinamis ("Tambah"/"Add")
            ),
          ],
        ),
      ),
    );
  }
}