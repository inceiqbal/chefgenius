import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/providers/connectivity_provider.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // Ngintip status koneksi dari provider
    final isOffline = context.watch<ConnectivityProvider>().isOffline;

    if (isOffline) {
      // Kalo offline, tampilin banner kuning
      return Container(
        width: double.infinity,
        color: Colors.amber[700],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text(
              'Anda sedang offline. Beberapa fitur mungkin dimatikan.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
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