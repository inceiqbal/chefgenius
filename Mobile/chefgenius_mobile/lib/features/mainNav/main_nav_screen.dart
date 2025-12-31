import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/data/providers/language_provider.dart';
import '../../../app/data/providers/connectivity_provider.dart';
import 'package:chefgenius/features/pantry/screens/pantry_screen.dart';
import '../recipe/screens/generate_recipe_screen.dart'; 
import '../auth/screens/profile_screen.dart';
// IMPORT LAYAR KOMUNITAS BARU
import '../community/screens/community_screen.dart';

class MainNavScreen extends StatefulWidget {
  final String email;
  const MainNavScreen({super.key, required this.email});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _selectedIndex = 0;
  
  // Global Keys for Refresh
  final GlobalKey<CommunityScreenState> _communityKey = GlobalKey();
  final GlobalKey<ProfileScreenState> _profileKey = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  void _onItemTapped(int index) {
    // Cek koneksi buat fitur online (Community & AI)
    final isOffline = context.read<ConnectivityProvider>().isOffline;
    
    // Index 1 (Community) dan Index 2 (AI) butuh internet
    if ((index == 1 || index == 2) && isOffline) { 
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            index == 1 
              ? 'Medsos butuh kuota Bestie! Cari sinyal dulu yuk.' 
              : 'Offline nih! Fitur AI butuh internet.'
          ), 
          backgroundColor: Colors.orange
        ),
      );
      return; 
    }

    if (_selectedIndex == index) {
      // Tap again to refresh
      if (index == 1) {
        _communityKey.currentState?.refresh();
      } else if (index == 3) {
        _profileKey.currentState?.refresh();
      }
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack( 
        index: _selectedIndex,
        children: [
          // Index 0: Pantry (Halaman Utama)
          PantryScreen(email: widget.email, isVisible: _selectedIndex == 0),

          // Index 1: Community (Inzara) - BARU!
          CommunityScreen(key: _communityKey),

          // Index 2: Generate Resep AI
          GenerateRecipeScreen(isVisible: _selectedIndex == 2), 

          // Index 3: Profile
          ProfileScreen(key: _profileKey, email: widget.email),
        ],
      ),
      // AppBar dihapus agar setiap halaman menggunakan AppBar masing-masing
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
          indicatorColor: Colors.orange.withValues(alpha: 0.2),
          elevation: 0,
          destinations: [
            // 1. Pantry
            NavigationDestination(
              icon: const Icon(Icons.kitchen_outlined),
              selectedIcon: const Icon(Icons.kitchen, color: Colors.orange),
              label: lang.getText('pantry_title'), 
            ),
            
            // 2. Community (BARU)
            NavigationDestination(
              icon: const Icon(Icons.people_outline),
              selectedIcon: const Icon(Icons.people, color: Colors.purpleAccent),
              label: lang.getText('nav_social'),
            ),

            // 3. Chef AI
            NavigationDestination(
              icon: const Icon(Icons.auto_awesome_outlined),
              selectedIcon: const Icon(Icons.auto_awesome, color: Colors.orange),
              label: lang.getText('nav_chef_ai'),
            ),

            // 4. Profile
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person, color: Colors.green),
              label: lang.getText('nav_profile'),
            ),
          ],
        ),
      ),
    );
  }
}