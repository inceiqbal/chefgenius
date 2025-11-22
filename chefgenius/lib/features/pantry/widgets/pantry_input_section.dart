import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

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
    return Showcase(
      key: showcaseKey,
      title: '1. Mulai Dari Sini!',
      description: 'Ketik bahan, atau klik tombol kamera untuk scan otomatis!',
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
                      ? 'Offline (Gak bisa nambah)'
                      : 'Masukkan bahan lain (e.g. Keju)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.add),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.camera_alt_rounded, color: Colors.purple),
                    tooltip: "Scan Isi Kulkas (Cei Vision)",
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
                  : const Text('Tambah'),
            ),
          ],
        ),
      ),
    );
  }
}