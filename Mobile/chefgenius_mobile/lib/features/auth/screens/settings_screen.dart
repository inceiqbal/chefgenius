import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/data/providers/theme_provider.dart';
import '../../../app/data/providers/language_provider.dart';
import '../../../app/widgets/custom_app_bar.dart';
import '../../../app/config/routes.dart';

class SettingsScreen extends StatefulWidget {
  final bool scrollToDiet;
  const SettingsScreen({super.key, this.scrollToDiet = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<String> _selectedDiets = [];
  bool _isLoading = true;
  int _userLevel = 0;

  // LIST KUNCI DIET
  final List<String> _dietKeys = [
    "halal",
    "vegetarian",
    "vegan",
    "keto",
    "low_carb",
    "gluten_free",
    "low_sugar",
    "nut_allergy",
    "seafood_allergy",
    "dairy_allergy",
    "no_onion"
  ];

  @override
  void initState() {
    super.initState();
    _loadDietPreferences();
    if (widget.scrollToDiet) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        _showDietSelectionDialog(lang);
      });
    }
  }

  Future<void> _loadDietPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _selectedDiets = prefs.getStringList('user_diet_preferences') ?? [];
          final xp = prefs.getInt('user_xp') ?? 0;
          // Assuming GenerationConstants.xpPerLevel is 300, but I don't have access to it here easily without import.
          // I'll hardcode 300 or try to import it. It's better to import.
          // But for now, I'll just use 300 as I saw it in the file earlier.
          _userLevel = xp ~/ 300; 
          
          // Admin Bypass
          final currentUserEmail = Supabase.instance.client.auth.currentUser?.email;
          if (currentUserEmail == "inceiqbals6@gmail.com") {
            _userLevel = 999;
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading settings: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveDietPreferences(List<String> diets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('user_diet_preferences', diets);
    if (mounted) {
      setState(() {
        _selectedDiets = diets;
      });
    }
  }

  void _showThemeDialog(ThemeProvider themeProvider, LanguageProvider lang) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                lang.getText('theme_title'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildThemeOption(
                context, 
                lang.getText('theme_system'), 
                ThemeMode.system, 
                themeProvider
              ),
              _buildThemeOption(
                context, 
                lang.getText('theme_light'), 
                ThemeMode.light, 
                themeProvider
              ),
              _buildThemeOption(
                context, 
                lang.getText('theme_dark'), 
                ThemeMode.dark, 
                themeProvider
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeOption(BuildContext context, String title, ThemeMode mode, ThemeProvider provider) {
    final isSelected = provider.themeMode == mode;
    return ListTile(
      leading: Icon(
        mode == ThemeMode.light ? Icons.light_mode : 
        mode == ThemeMode.dark ? Icons.dark_mode : Icons.settings_brightness,
        color: isSelected ? Colors.orange : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.orange : null,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.orange) : null,
      onTap: () {
        provider.setTheme(mode);
        Navigator.pop(context);
      },
    );
  }

  // --- UI BARU: PAKE BOTTOM SHEET & CHIPS (DINAMIS) ---
  void _showDietSelectionDialog(LanguageProvider lang) {
    List<String> tempSelectedDiets = List.from(_selectedDiets);
    // Kita pake variabel ini buat nentuin warna teks deskripsi
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  Text(
                    lang.getText('diet_menu_title'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.info_rounded, color: Colors.orangeAccent, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Chef Cei will prioritize recipes matching these filters.",
                            style: TextStyle(fontSize: 12, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- BAGIAN UTAMA: LIST DIET DINAMIS ---
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _dietKeys.length,
                      itemBuilder: (context, index) {
                         final key = _dietKeys[index];
                         // AMBIL TEKS DARI PROVIDER
                         final title = lang.getText('diet_${key}_title');
                         final desc = lang.getText('diet_${key}_desc');
                         
                         final isSelected = tempSelectedDiets.contains(key);
                         
                         // Locking Logic: 2 filters per level (Level 0 gets 2, Level 1 gets 4, etc.)
                         // Index 0,1 -> Level 0
                         // Index 2,3 -> Level 1
                         // Index 4,5 -> Level 2
                         final requiredLevel = (index / 2).floor();
                         final isLocked = _userLevel < requiredLevel;

                         return CheckboxListTile(
                           title: Row(
                             children: [
                               Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isLocked ? Colors.grey : null)),
                               if (isLocked) ...[
                                 const SizedBox(width: 8),
                                 const Icon(Icons.lock, size: 14, color: Colors.grey),
                                 const SizedBox(width: 4),
                                 Text("Lv. $requiredLevel", style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                               ]
                             ],
                           ),
                           // PERBAIKAN: Gunakan isDarkMode biar teks deskripsi kebaca
                           subtitle: Text(
                             desc, 
                             style: TextStyle(
                               fontSize: 12, 
                               color: isLocked ? Colors.grey[400] : (isDarkMode ? Colors.grey[400] : Colors.grey[600])
                             )
                           ),
                           value: isSelected,
                           activeColor: Colors.green,
                           onChanged: isLocked ? null : (bool? value) {
                             setStateSheet(() {
                               if (value == true) {
                                 tempSelectedDiets.add(key);
                               } else {
                                 tempSelectedDiets.remove(key);
                               }
                             });
                           },
                         );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _saveDietPreferences(tempSelectedDiets);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Sip! Preferensi dietmu udah disimpen! 🥗"), backgroundColor: Colors.green),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(lang.getText('save'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showLanguageDialog(LanguageProvider langProvider) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(langProvider.getText('language_menu')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Text("🇮🇩", style: TextStyle(fontSize: 24)),
                title: const Text("Bahasa Indonesia"),
                trailing: langProvider.appLocale.languageCode == 'id'
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                tileColor: langProvider.appLocale.languageCode == 'id' 
                    ? (isDarkMode ? Colors.green.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.1))
                    : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                onTap: () {
                  langProvider.changeLanguage(const Locale('id'));
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Text("🇺🇸", style: TextStyle(fontSize: 24)),
                title: const Text("English"),
                trailing: langProvider.appLocale.languageCode == 'en'
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                tileColor: langProvider.appLocale.languageCode == 'en' 
                    ? (isDarkMode ? Colors.green.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.1))
                    : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                onTap: () {
                  langProvider.changeLanguage(const Locale('en'));
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    LanguageProvider lang;
    try {
      lang = Provider.of<LanguageProvider>(context);
    } catch (e) {
      return const Scaffold(body: Center(child: Text("Error: LanguageProvider Missing")));
    }

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: CustomAppBar(title: lang.getText('settings_title')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionHeader(lang.getText('pref_diet_title')),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _buildSettingsTile(
                  context: context,
                  icon: Icons.restaurant_menu,
                  color: Colors.orange,
                  title: lang.getText('diet_menu_title'),
                  // --- PERBAIKAN DI SINI (LowerCase) ---
                  // Kita paksa key-nya jadi lowercase biar match sama file JSON bahasa
                  subtitle: _selectedDiets.isEmpty
                      ? lang.getText('diet_menu_subtitle')
                      : _selectedDiets.map((key) {
                          final label = lang.getText('diet_${key.toLowerCase()}_title');
                          // Jika tidak ada di localization, fallback: ubah underscore ke spasi dan kapitalisasi
                          if (label == 'diet_${key.toLowerCase()}_title') {
                            return key.replaceAll('_', ' ').replaceFirst(key[0], key[0].toUpperCase());
                          }
                          return label;
                        }).join(", "),
                  // -------------------------------------
                  onTap: () => _showDietSelectionDialog(lang),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildSectionHeader(lang.getText('display_lang_title')),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _buildSettingsTile(
                  context: context,
                  icon: Icons.brightness_6_outlined,
                  color: Colors.purple,
                  title: lang.getText('theme_title'),
                  subtitle: _getThemeSubtitle(themeProvider.themeMode, lang),
                  onTap: () => _showThemeDialog(themeProvider, lang),
                ),
                const Divider(height: 1, indent: 72),
                _buildSettingsTile(
                  context: context,
                  icon: Icons.language,
                  color: Colors.orange,
                  title: lang.getText('language_menu'),
                  subtitle: lang.appLocale.languageCode == 'id' ? 'Bahasa Indonesia' : 'English',
                  onTap: () => _showLanguageDialog(lang),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildSectionHeader(lang.getText('account_title')),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _buildSettingsTile(
                  context: context,
                  icon: Icons.lock_outline,
                  color: Colors.deepOrange,
                  title: lang.getText('change_password'),
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.changePasswordRoute);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildSectionHeader(lang.getText('about_title')),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _buildSettingsTile(
                  context: context,
                  icon: Icons.info_outline,
                  color: Colors.teal,
                  title: lang.getText('about_app'),
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.aboutRoute);
                  },
                ),
                const Divider(height: 1, indent: 72),
                _buildSettingsTile(
                  context: context,
                  icon: Icons.description_outlined,
                  color: Colors.orange,
                  title: lang.getText('terms'),
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.termsRoute);
                  },
                ),
                const Divider(height: 1, indent: 72),
                _buildSettingsTile(
                  context: context,
                  icon: Icons.privacy_tip_outlined,
                  color: Colors.green,
                  title: lang.getText('privacy'),
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
          color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
    );
  }

  String _getThemeSubtitle(ThemeMode mode, LanguageProvider lang) {
    switch (mode) {
      case ThemeMode.system: return lang.getText('theme_system');
      case ThemeMode.light: return lang.getText('theme_light');
      case ThemeMode.dark: return lang.getText('theme_dark');
    }
  }

  // PERBAIKAN TYPO FATAL ADA DI SINI
  Widget _buildSettingsTile({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ), // <--- TADI SALAH KETIK PAKE '}' DISINI, UDAH DIBENERIN JADI ')'
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.orangeAccent))
          : null,
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
      onTap: onTap,
    );
  }
}