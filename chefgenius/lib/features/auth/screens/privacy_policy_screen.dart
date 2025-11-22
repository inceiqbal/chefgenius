import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  static const String routeName = '/privacy-policy';

  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Mengambil style tema default untuk teks
    final textTheme = Theme.of(context).textTheme;    
    final bodyStyle = textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface);
    final headingStyle = textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kebijakan Privasi'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: RichText(
          textAlign: TextAlign.justify,
          text: TextSpan(
            style: bodyStyle, // Style default untuk semua teks
            children: [
              TextSpan(
                text: 'Kebijakan Privasi Aplikasi Chef Genius\n',
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
              ),
              
              const TextSpan(text: 'Terakhir diperbarui: 11 November 2025\n\n'),
              const TextSpan(
                text: 'Kami di Chef Genius ("kami", "kita") menghargai privasi Anda. Kebijakan Privasi ini menjelaskan bagaimana kami mengumpulkan, menggunakan, dan melindungi informasi Anda saat Anda menggunakan aplikasi seluler kami ("Aplikasi").\n\n',
              ),
              TextSpan(text: '1. Informasi yang Kami Kumpulkan\n', style: headingStyle),
              const TextSpan(
                text: 'Kami mengumpulkan informasi yang Anda berikan secara langsung saat mendaftar:\n'
                    '•  Nama (saat Anda mengedit profil).\n'
                    '•  Alamat email.\n'
                    '•  Password (disimpan dalam format terenkripsi).\n\n'
                    'Kami juga mengumpulkan data yang Anda buat di dalam aplikasi:\n'
                    '•  Daftar bahan di Pantry Anda.\n'
                    '•  Resep yang Anda simpan ke Favorit.\n\n',
              ),
              TextSpan(text: '2. Bagaimana Kami Menggunakan Informasi Anda\n', style: headingStyle),
              const TextSpan(
                text: 'Kami menggunakan informasi Anda untuk:\n'
                    '•  Membuat dan mengelola akun Anda (Otentikasi).\n'
                    '•  Mengizinkan Anda login dan melakukan reset password.\n'
                    '•  Menyediakan fitur inti aplikasi, seperti merekomendasikan resep berdasarkan Pantry Anda.\n'
                    '•  Menyimpan resep favorit Anda.\n\n',
              ),
              TextSpan(text: '3. Penyimpanan dan Keamanan Data\n', style: headingStyle),
              const TextSpan(
                text: 'Data Anda disimpan dengan aman menggunakan layanan pihak ketiga yang tepercaya, yaitu Supabase. Kami menerapkan langkah-langkah keamanan yang wajar untuk melindungi informasi Anda dari akses yang tidak sah. Password Anda di-hash dan dienkripsi.\n\n',
              ),
              TextSpan(text: '4. Berbagi Informasi\n', style: headingStyle),
              const TextSpan(
                text: 'Kami TIDAK akan menjual, menyewakan, atau membagikan informasi pribadi Anda (seperti email atau nama) kepada pihak ketiga untuk tujuan pemasaran.\n\n',
              ),
              TextSpan(text: '5. Kontrol Anda\n', style: headingStyle),
              const TextSpan(
                text: 'Anda memiliki hak untuk mengakses dan memperbarui informasi profil Anda kapan saja melalui halaman "Edit Profil".\n\n',
              ),
              TextSpan(text: '6. Kontak Kami\n', style: headingStyle),
              const TextSpan(
                text: 'Jika Anda memiliki pertanyaan tentang Kebijakan Privasi ini, silakan hubungi kami di instagram @inceiqbal atau whatsapp 087845245720 .\n',
              ),
            ],
          ),
        ),
      ),
    );
  }
}