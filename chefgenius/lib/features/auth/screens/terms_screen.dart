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
    final headingStyle = textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Syarat & Ketentuan'),
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
                text: 'Syarat & Ketentuan Penggunaan Aplikasi Chef Genius\n',
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
              ),
              const TextSpan(text: 'Terakhir diperbarui: 11 November 2025\n\n'),
              TextSpan(
                text: 'Selamat datang di Chef Genius!\n\n',
                style: headingStyle,
              ),
              const TextSpan(
                text:
                    'Dengan mengunduh, mengakses, atau menggunakan aplikasi seluler Chef Genius ("Aplikasi"), Anda setuju untuk terikat oleh Syarat & Ketentuan ("S&K") ini. Jika Anda tidak menyetujui S&K ini, mohon untuk tidak menggunakan Aplikasi.\n\n',
              ),
              TextSpan(text: '1. Akun Pengguna\n', style: headingStyle),
              const TextSpan(
                text:
                    '1.1. Pendaftaran: Untuk mengakses fitur tertentu, seperti menyimpan resep favorit, Anda harus mendaftar dan membuat akun. Anda setuju untuk memberikan informasi yang akurat dan lengkap.\n'
                    '1.2. Keamanan Akun: Anda bertanggung jawab penuh untuk menjaga kerahasiaan kata sandi dan akun Anda. Anda setuju untuk segera memberi tahu kami jika ada penggunaan akun Anda tanpa izin.\n\n',
              ),
              TextSpan(text: '2. Penggunaan Aplikasi\n', style: headingStyle),
              const TextSpan(
                text:
                    '2.1. Tujuan: Aplikasi ini dirancang untuk memberikan inspirasi resep masakan, manajemen bahan (pantry), dan generasi resep menggunakan kecerdasan buatan (AI).\n'
                    '2.2. Lisensi: Kami memberi Anda lisensi terbatas, non-eksklusif, dan tidak dapat dialihkan untuk menggunakan Aplikasi untuk keperluan pribadi dan non-komersial.\n\n',
              ),
              TextSpan(text: '3. Penafian (Disclaimer) Resep AI\n', style: headingStyle),
              const TextSpan(
                text:
                    '3.1. Sifat Generatif: Fitur resep AI ("Resep AI") menghasilkan resep secara otomatis. Resep yang dihasilkan mungkin belum teruji, unik, atau eksperimental.\n'
                    '3.2. Batas Tanggung Jawab: Resep AI disediakan "APA ADANYA" untuk tujuan informasi dan inspirasi. Kami tidak menjamin keakuratan, kelayakan, keamanan, atau hasil dari resep yang dihasilkan AI.\n'
                    '3.3. Risiko Pengguna: Anda bertanggung jawab penuh atas penggunaan resep AI. Harap gunakan penilaian terbaik Anda, periksa kembali bahan dan langkah-langkah, dan pastikan keamanan pangan (misalnya, alergi, metode memasak yang tepat) sebelum mencoba resep apa pun. Chef Genius tidak bertanggung jawab atas cedera, kerugian, atau kerusakan apa pun (termasuk keracunan makanan atau reaksi alergi) yang timbul dari penggunaan resep AI.\n\n',
              ),
              TextSpan(text: '4. Kebijakan Privasi\n', style: headingStyle),
              const TextSpan(
                text:
                    'Penggunaan Anda atas Aplikasi juga diatur oleh Kebijakan Privasi kami [Nanti kita buat link di sini], yang menjelaskan bagaimana kami mengumpulkan dan menggunakan data pribadi Anda (seperti email untuk login dan reset password).\n\n',
              ),
              TextSpan(text: '5. Perubahan S&K\n', style: headingStyle),
              const TextSpan(
                text:
                    'Kami berhak untuk mengubah S&K ini kapan saja. Kami akan memberi tahu Anda tentang perubahan materi dengan memposting S&K baru di Aplikasi. Penggunaan Anda yang berkelanjutan setelah perubahan tersebut merupakan penerimaan Anda terhadap S&K yang baru.\n',
              ),
            ],
          ),
        ),
      ),
    );
  }
}