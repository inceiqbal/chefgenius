import 'package:flutter/material.dart';
import '../../../app/widgets/custom_app_bar.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const String appVersion = "1.0.0";

    return Scaffold(
      appBar: const CustomAppBar(title: 'Tentang Aplikasi'),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),

                    // Logo
                    Image.asset(
                      'assets/images/icon_chefgenius.png',
                      height: 120,
                    ),
                    const SizedBox(height: 24),

                    // Judul
                    const Text(
                      'Chef Genius',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Versi aplikasi
                    Text(
                      'Versi $appVersion',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Deskripsi
                    const Text(
                      'Chef Genius adalah asisten masak cerdas pribadi Anda. Aplikasi ini dirancang untuk membantu Anda menemukan inspirasi resep masakan berdasarkan bahan-bahan yang Anda miliki, mengurangi limbah makanan, dan membuat proses memasak menjadi lebih mudah dan menyenangkan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 8),

                    // 🔥 ListTile Syarat & Ketentuan → DIHAPUS
                    // 🔥 ListTile Kebijakan Privasi → DIHAPUS
                  ],
                ),
              ),
            ),

            // Footer
            const SizedBox(height: 16),
            Text(
              '© 2025 - Proyek IPPL',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}