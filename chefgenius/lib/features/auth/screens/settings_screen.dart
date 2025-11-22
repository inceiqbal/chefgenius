import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Wajib import ini buat nyimpen data
import '../../../app/data/providers/theme_provider.dart';
import '../../../app/widgets/custom_app_bar.dart';
import '../../../app/config/routes.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Data Preferensi Diet
  List<String> _selectedDiets = [];
  
  // Opsi yang tersedia (Bisa ditambahin sesuka hati)
  final List<String> _dietOptions = [
    "Halal",
    "Vegetarian",
    "Vegan",
    "Keto",
    "Low Carb",
    "Bebas Gluten (Gluten Free)",
    "Rendah Gula (Diabetic Friendly)",
    "Alergi Kacang",
    "Alergi Seafood",
    "Alergi Susu (Lactose Intolerant)",
    "Tanpa Bawang (Jain Diet)"
  ];

  @override
  void initState() {
    super.initState();
    _loadDietPreferences();
  }

  // Load data dari memori HP
  Future<void> _loadDietPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedDiets = prefs.getStringList('user_diet_preferences') ?? [];
    });
  }

  // Save data ke memori HP
  Future<void> _saveDietPreferences(List<String> diets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('user_diet_preferences', diets);
    setState(() {
      _selectedDiets = diets;
    });
  }

  // Munculin Dialog Pilihan Diet
  void _showDietSelectionDialog() {
    // Bikin list sementara biar gak langsung ngerubah state utama sebelum klik Simpan
    List<String> tempSelectedDiets = List.from(_selectedDiets);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Preferensi Makanan"),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _dietOptions.length,
                  itemBuilder: (context, index) {
                    final option = _dietOptions[index];
                    final isSelected = tempSelectedDiets.contains(option);

                    return CheckboxListTile(
                      title: Text(option),
                      value: isSelected,
                      activeColor: Theme.of(context).primaryColor,
                      onChanged: (bool? value) {
                        setStateDialog(() {
                          if (value == true) {
                            tempSelectedDiets.add(option);
                          } else {
                            tempSelectedDiets.remove(option);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Batal", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    _saveDietPreferences(tempSelectedDiets);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Preferensi diet disimpan! Chef Cei bakal inget ini.")),
                    );
                  },
                  child: const Text("Simpan"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: const CustomAppBar(title: 'Pengaturan'),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- FITUR BARU: DIET PROFILE (ANTI-AMNESIA) ---
          _buildSectionHeader('Preferensi Saya (Anti-Amnesia)'),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _buildSettingsTile(
                  context: context,
                  icon: Icons.restaurant_menu,
                  color: Colors.orange,
                  title: 'Pantangan & Diet',
                  // Nampilin preview diet yang dipilih di subtitle
                  subtitle: _selectedDiets.isEmpty 
                      ? "Tidak ada pantangan khusus" 
                      : _selectedDiets.join(", "), 
                  onTap: _showDietSelectionDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // -----------------------------------------------

          _buildSectionHeader('Akun'),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _buildSettingsTile(
                  context: context,
                  icon: Icons.lock_outline,
                  color: Colors.blueGrey,
                  title: 'Ubah Password',
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.changePasswordRoute);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Tampilan'),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined, color: Colors.purple),
                  title: const Text('Mode Gelap'),
                  value: themeProvider.isDarkMode,
                  onChanged: (bool value) {
                    themeProvider.toggleTheme(value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Tentang'),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _buildSettingsTile(
                  context: context,
                  icon: Icons.info_outline,
                  color: Colors.teal,
                  title: 'Tentang Chef Genius',
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.aboutRoute);
                  },
                ),
                const Divider(height: 1, indent: 72),
                _buildSettingsTile(
                  context: context,
                  icon: Icons.description_outlined,
                  color: Colors.orange,
                  title: 'Syarat & Ketentuan',
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.termsRoute);
                  },
                ),
                const Divider(height: 1, indent: 72),
                _buildSettingsTile(
                  context: context,
                  icon: Icons.privacy_tip_outlined,
                  color: Colors.green,
                  title: 'Kebijakan Privasi',
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.privacyPolicyRoute);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle, // Tambahan parameter subtitle
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: subtitle != null 
          ? Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.blueAccent)) 
          : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}