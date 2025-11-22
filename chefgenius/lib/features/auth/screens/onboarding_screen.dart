import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../app/config/routes.dart'; 

class OnboardingScreen extends StatefulWidget {
  static const String routeName = '/onboarding';

  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // --- UPGRADE: Update Konten Onboarding ---
  final List<Widget> _pages = [
    // Halaman 1: Intro
    _buildOnboardingPage(
      icon: Icons.soup_kitchen_rounded,
      title: 'Selamat Datang di\nChef Genius!',
      description:
          'Asisten dapur pintar yang siap menyulap bahan sisa jadi hidangan istimewa. Masak jadi gampang dan seru!',
    ),
    // Halaman 2: Cei Vision
    _buildOnboardingPage(
      icon: Icons.camera_alt_rounded, // Icon Kamera
      title: 'Fitur "Cei Vision"',
      description:
          'Males ngetik? Cukup FOTO isi kulkasmu, AI kami akan otomatis mengenali bahannya dan memasukkannya ke Pantry. Ajaib!',
    ),
    // Halaman 3: Chef Cei (Fitur Utama)
    _buildOnboardingPage(
      icon: Icons.psychology_alt,
      title: 'Tanya Chef Cei',
      description:
          'Bingung mau masak apa? Minta Chef Cei buatkan resep unik khusus untukmu. Bisa atur gaya koki dari Nenek Penyayang sampai Chef Galak!',
    ),
    // Halaman 4: Leveling (Fitur Baru!)
    _buildOnboardingPage(
      icon: Icons.emoji_events_rounded, // Icon Piala
      title: 'Masak & Level Up!',
      description:
          'Dapatkan XP setiap selesai memasak. Naikkan levelmu dari "Anak Kos" menjadi "Master Chef" dan buka fitur-fitur rahasia!',
    ),
  ];

  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.loginRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // --- Bagian Slideshow ---
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: _pages,
              ),
            ),

            // --- Bagian Indikator Titik-Titik ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(_pages.length, (int index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 8,
                  width: (index == _currentPage) ? 24 : 8, // Sedikit lebih kecil biar elegan
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 30),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: (index == _currentPage)
                        ? Theme.of(context).primaryColor
                        : Colors.grey[300],
                  ),
                );
              }),
            ),

            // --- Bagian Tombol ---
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12), // Lebih membulat
                  ),
                ),
                onPressed: () {
                  if (_currentPage == _pages.length - 1) {
                    _finishOnboarding(); 
                  } else {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: Text(
                  _currentPage == _pages.length - 1
                      ? 'Mulai Masak Sekarang!'
                      : 'Lanjut',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildOnboardingPage({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Lingkaran Background Icon biar makin manis
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 100,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}