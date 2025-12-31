import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // IMPORT PROVIDER
import 'package:shared_preferences/shared_preferences.dart';
import '../../../app/config/routes.dart'; 
import '../../../app/data/providers/language_provider.dart'; // IMPORT LANG PROVIDER

class OnboardingScreen extends StatefulWidget {
  static const String routeName = '/onboarding';

  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.loginRoute);
    }
  }

  // Helper widget sekarang lebih canggih! Bisa Icon, bisa Gambar.
  static Widget _buildOnboardingPage({
    IconData? icon,          // Jadi nullable (boleh kosong kalau pake gambar)
    String? imagePath,       // Parameter baru buat gambar
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Lingkaran Background
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            // Logika Cerdas: Tampilkan Gambar kalau ada imagePath, kalau gak ada tampilkan Icon
            child: imagePath != null
                ? Image.asset(
                    imagePath,
                    height: 120, // Sesuaikan tinggi gambar biar pas
                    width: 120,
                    fit: BoxFit.contain,
                  )
                : Icon(
                    icon,
                    size: 100,
                    color: Colors.orangeAccent,
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

  @override
  Widget build(BuildContext context) {
    // 1. PANGGIL BAHASA
    final lang = context.watch<LanguageProvider>();

    // 2. LIST PAGES
    final List<Widget> pages = [
      // Halaman 1: Intro (SEKARANG PAKE GAMBAR HELLO.PNG) 👋
      _buildOnboardingPage(
        imagePath: 'assets/icons/hello.png', // Pake path asset, bukan absolute path Windows
        title: lang.getText('onboard_1_title'),
        description: lang.getText('onboard_1_desc'),
      ),
      // Halaman 2: Cei Vision
      _buildOnboardingPage(
        icon: Icons.camera_alt_rounded,
        title: lang.getText('onboard_2_title'),
        description: lang.getText('onboard_2_desc'),
      ),
      // Halaman 3: Chef Cei
      _buildOnboardingPage(
        icon: Icons.auto_awesome,
        title: lang.getText('onboard_3_title'),
        description: lang.getText('onboard_3_desc'),
      ),
      // Halaman 4: Leveling
      _buildOnboardingPage(
        icon: Icons.emoji_events_rounded,
        title: lang.getText('onboard_4_title'),
        description: lang.getText('onboard_4_desc'),
      ),
      // Halaman 5: Inzara Community
      _buildOnboardingPage(
        icon: Icons.people_alt_rounded,
        title: lang.getText('onboard_5_title'),
        description: lang.getText('onboard_5_desc'),
      ),
    ];

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
                children: pages,
              ),
            ),

            // --- Bagian Indikator Titik-Titik ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(pages.length, (int index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 8,
                  width: (index == _currentPage) ? 24 : 8, 
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
                    borderRadius: BorderRadius.circular(12), 
                  ),
                ),
                onPressed: () {
                  if (_currentPage == pages.length - 1) {
                    _finishOnboarding(); 
                  } else {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: Text(
                  _currentPage == pages.length - 1
                      ? lang.getText('onboard_btn_start')
                      : lang.getText('onboard_btn_next'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}