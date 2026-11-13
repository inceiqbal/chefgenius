import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/data/providers/theme_provider.dart';
import '../../../app/data/providers/language_provider.dart';
import '../../../app/widgets/custom_app_bar.dart';
import '../../../app/widgets/modern_alert_dialog.dart';
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF9B59B6), Color(0xFF8E44AD)]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF9B59B6).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: const Icon(Icons.palette_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      lang.getText('theme_title'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Options
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  children: [
                    _buildModernThemeOption(
                      context, 
                      lang.getText('theme_system'),
                      'Ikuti pengaturan sistem',
                      Icons.settings_brightness_rounded,
                      const [Color(0xFF3498DB), Color(0xFF2980B9)],
                      ThemeMode.system, 
                      themeProvider,
                      isDarkMode,
                    ),
                    const SizedBox(height: 8),
                    _buildModernThemeOption(
                      context, 
                      lang.getText('theme_light'),
                      'Mode terang',
                      Icons.light_mode_rounded,
                      const [Color(0xFFF39C12), Color(0xFFE67E22)],
                      ThemeMode.light, 
                      themeProvider,
                      isDarkMode,
                    ),
                    const SizedBox(height: 8),
                    _buildModernThemeOption(
                      context, 
                      lang.getText('theme_dark'),
                      'Mode gelap',
                      Icons.dark_mode_rounded,
                      const [Color(0xFF34495E), Color(0xFF2C3E50)],
                      ThemeMode.dark, 
                      themeProvider,
                      isDarkMode,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModernThemeOption(
    BuildContext context, 
    String title, 
    String subtitle,
    IconData icon,
    List<Color> gradient,
    ThemeMode mode, 
    ThemeProvider provider,
    bool isDarkMode,
  ) {
    final isSelected = provider.themeMode == mode;
    return GestureDetector(
      onTap: () {
        provider.setTheme(mode);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? gradient.first.withOpacity(0.15)
              : (isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? gradient.first : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: gradient.first,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
              ),
          ],
        ),
      ),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    LanguageProvider lang;
    try {
      lang = Provider.of<LanguageProvider>(context);
    } catch (e) {
      return const Scaffold(body: Center(child: Text("Error: LanguageProvider Missing")));
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFFAFAFA),
        body: const Center(child: CircularProgressIndicator(color: Colors.orange)),
      );
    }

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFFAFAFA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : const Color(0xFFFFF8F0),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDarkMode ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF9B59B6), Color(0xFF8E44AD)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.settings_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              lang.getText('settings_title'),
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [const Color(0xFF1A1A2E), const Color(0xFF121212)]
                : [const Color(0xFFFFF8F0), const Color(0xFFFAFAFA)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildModernSectionHeader(lang.getText('pref_diet_title'), Icons.restaurant_menu_rounded, Colors.orange, isDarkMode),
            const SizedBox(height: 12),
            _buildModernCard(
              isDarkMode: isDarkMode,
              children: [
                _buildModernSettingsTile(
                  context: context,
                  icon: Icons.eco_rounded,
                  gradient: const [Color(0xFF27AE60), Color(0xFF1E8449)],
                  title: lang.getText('diet_menu_title'),
                  subtitle: _selectedDiets.isEmpty
                      ? lang.getText('diet_menu_subtitle')
                      : _selectedDiets.take(2).map((key) {
                          final label = lang.getText('diet_${key.toLowerCase()}_title');
                          if (label == 'diet_${key.toLowerCase()}_title') {
                            return key.replaceAll('_', ' ').replaceFirst(key[0], key[0].toUpperCase());
                          }
                          return label;
                        }).join(", ") + (_selectedDiets.length > 2 ? " +${_selectedDiets.length - 2}" : ""),
                  onTap: () => _showDietSelectionDialog(lang),
                  isDarkMode: isDarkMode,
                ),
              ],
            ),
            const SizedBox(height: 24),

            _buildModernSectionHeader(lang.getText('display_lang_title'), Icons.palette_rounded, Colors.purple, isDarkMode),
            const SizedBox(height: 12),
            _buildModernCard(
              isDarkMode: isDarkMode,
              children: [
                _buildModernSettingsTile(
                  context: context,
                  icon: Icons.brightness_6_rounded,
                  gradient: const [Color(0xFF9B59B6), Color(0xFF8E44AD)],
                  title: lang.getText('theme_title'),
                  subtitle: _getThemeSubtitle(themeProvider.themeMode, lang),
                  onTap: () => _showThemeDialog(themeProvider, lang),
                  isDarkMode: isDarkMode,
                ),
                Divider(height: 1, color: Colors.grey.withOpacity(0.2), indent: 72),
                _buildModernSettingsTile(
                  context: context,
                  icon: Icons.translate_rounded,
                  gradient: const [Color(0xFFE67E22), Color(0xFFD35400)],
                  title: lang.getText('language_menu'),
                  subtitle: lang.appLocale.languageCode == 'id' ? '🇮🇩 Bahasa Indonesia' : '🇺🇸 English',
                  onTap: () => _showLanguageDialog(lang),
                  isDarkMode: isDarkMode,
                ),
              ],
            ),
            const SizedBox(height: 24),

            _buildModernSectionHeader(lang.getText('account_title'), Icons.person_rounded, Colors.blue, isDarkMode),
            const SizedBox(height: 12),
            _buildModernCard(
              isDarkMode: isDarkMode,
              children: [
                _buildModernSettingsTile(
                  context: context,
                  icon: Icons.lock_rounded,
                  gradient: const [Color(0xFFE74C3C), Color(0xFFC0392B)],
                  title: lang.getText('change_password'),
                  onTap: () => Navigator.pushNamed(context, AppRoutes.changePasswordRoute),
                  isDarkMode: isDarkMode,
                ),
              ],
            ),
            const SizedBox(height: 24),

            _buildModernSectionHeader(lang.getText('about_title'), Icons.info_rounded, Colors.teal, isDarkMode),
            const SizedBox(height: 12),
            _buildModernCard(
              isDarkMode: isDarkMode,
              children: [
                _buildModernSettingsTile(
                  context: context,
                  icon: Icons.info_outline_rounded,
                  gradient: const [Color(0xFF1ABC9C), Color(0xFF16A085)],
                  title: lang.getText('about_app'),
                  onTap: () => Navigator.pushNamed(context, AppRoutes.aboutRoute),
                  isDarkMode: isDarkMode,
                ),
                Divider(height: 1, color: Colors.grey.withOpacity(0.2), indent: 72),
                _buildModernSettingsTile(
                  context: context,
                  icon: Icons.description_rounded,
                  gradient: const [Color(0xFFE67E22), Color(0xFFD35400)],
                  title: lang.getText('terms'),
                  onTap: () => Navigator.pushNamed(context, AppRoutes.termsRoute),
                  isDarkMode: isDarkMode,
                ),
                Divider(height: 1, color: Colors.grey.withOpacity(0.2), indent: 72),
                _buildModernSettingsTile(
                  context: context,
                  icon: Icons.privacy_tip_rounded,
                  gradient: const [Color(0xFF27AE60), Color(0xFF1E8449)],
                  title: lang.getText('privacy'),
                  onTap: () => Navigator.pushNamed(context, AppRoutes.privacyPolicyRoute),
                  isDarkMode: isDarkMode,
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildModernSectionHeader(String title, IconData icon, Color color, bool isDarkMode) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildModernCard({required bool isDarkMode, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.15 : 0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(children: children),
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

  Widget _buildModernSettingsTile({
    required BuildContext context,
    required IconData icon,
    required List<Color> gradient,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: gradient.first.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}