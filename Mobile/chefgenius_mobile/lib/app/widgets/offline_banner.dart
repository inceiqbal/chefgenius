import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/providers/connectivity_provider.dart';
import '../data/providers/language_provider.dart'; // IMPORT LANG PROVIDER

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. WATCH LANGUAGE PROVIDER
    final lang = context.watch<LanguageProvider>();
    
    // Ngintip status koneksi dari provider
    final isOffline = context.watch<ConnectivityProvider>().isOffline;

    if (isOffline) {
      // Kalo offline, tampilin banner kuning
      return Container(
        width: double.infinity,
        color: Colors.amber[700],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Flexible( // Pake Flexible biar teks gak overflow di HP kecil
              child: Text(
                lang.getText('offline_banner'), // Teks Dinamis
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    } else {
      // Kalo online, gak nampilin apa-apa
      return const SizedBox.shrink();
    }
  }
}