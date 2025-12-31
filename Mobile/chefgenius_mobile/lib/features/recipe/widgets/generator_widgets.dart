import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../../app/data/utils/generation_constants.dart'; 
import '../../../app/data/providers/language_provider.dart';
import '../../auth/screens/settings_screen.dart';

// --- HELPER WIDGET: BUBBLE CHEF CEI ---
class _CeiShowcaseBubble extends StatelessWidget {
  final String title;
  final String description;

  const _CeiShowcaseBubble({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 230, 
      width: 260, 
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.orange.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8)),
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2)),
        ],
        border: Border.all(color: Colors.orange.withOpacity(0.1), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pastikan path image ini valid di project kamu
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.orange.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 4))
              ]
            ),
            child: Image.asset('assets/images/Chef_Cei/chefceiguide.png', height: 100, fit: BoxFit.contain),
          ),
          const SizedBox(height: 12),
          Text(
            title, 
            textAlign: TextAlign.center, 
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.orange.shade800)
          ),
          const SizedBox(height: 6),
          Text(
            description, 
            textAlign: TextAlign.center, 
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4)
          ),
        ],
      ),
    );
  }
}

// --- WIDGET 1: PROMPT INPUT (SHOWCASE 1) ---
class PromptInputSection extends StatelessWidget {
  final GlobalKey showcaseKey;
  final TextEditingController controller;
  final bool isOffline;
  final VoidCallback onInfoPressed;
  final List<String> userDietPreferences;
  final int userLevel;
  final VoidCallback? onSettingsChanged;

  const PromptInputSection({
    super.key,
    required this.showcaseKey,
    required this.controller,
    required this.isOffline,
    required this.onInfoPressed,
    required this.userDietPreferences,
    required this.userLevel,
    this.onSettingsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Showcase.withWidget(
      key: showcaseKey,
      targetShapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
      container: _CeiShowcaseBubble(
        title: lang.getText('showcase_1_title'), 
        description: lang.getText('showcase_1_desc'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.orange.shade400, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    lang.getText('gen_section_title'), 
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 20, color: Colors.grey),
                onPressed: onInfoPressed,
                tooltip: lang.getText('gen_info_btn'), 
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.orange.withOpacity(0.2)),
            ),
            child: TextField(
              controller: controller,
              enabled: !isOffline,
              maxLines: 4,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: isOffline 
                    ? lang.getText('gen_btn_offline') 
                    : lang.getText('gen_hint_online'),
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          
          if (userDietPreferences.isNotEmpty)
            userLevel >= 5 
            ? GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen(scrollToDiet: true)),
                  ).then((_) {
                    if (onSettingsChanged != null) onSettingsChanged!();
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          "${lang.getText('gen_filter_active')} " +
                            userDietPreferences.map((key) {
                              final label = lang.getText('diet_${key.toLowerCase()}_title');
                              if (label == 'diet_${key.toLowerCase()}_title') {
                                // Fallback: Capitalize each word and replace underscores
                                return key.replaceAll('_', ' ').split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '').join(' ');
                              }
                              return label;
                            }).join(', '),
                          style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit, color: Colors.green, size: 12),
                    ],
                  ),
                ),
              )
            : Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock, color: Colors.grey, size: 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      "Diet Filter Locked (Lv 5)", 
                      style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            )
          else 
            const SizedBox.shrink(), 
        ],
      ),
    );
  }
}

// --- WIDGET 2: PERSONA SELECTOR (SHOWCASE 2) ---
class PersonaSelectorWidget extends StatelessWidget {
  final GlobalKey showcaseKey;
  final String selectedPersonaKey;
  final int userLevel;
  final bool isOffline;
  final Function(String) onSelect;

  const PersonaSelectorWidget({
    super.key,
    required this.showcaseKey,
    required this.selectedPersonaKey,
    required this.userLevel,
    required this.isOffline,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    if (isOffline) return const SizedBox.shrink();

    // --- LOGIKA BUILDER GAMBAR CUSTOM ---
    Widget buildPersonaVisual(String key, bool isSelected) {
      final Color? iconColor = isSelected ? Colors.orange.shade700 : Colors.grey.shade600;

      switch (key) {
        case 'grandma': 
          return Image.asset('assets/icons/grandmother (1).png', width: 40, height: 40, color: iconColor);
        case 'nutritionist': 
          return Image.asset('assets/icons/nutritionist.png', width: 40, height: 40, color: iconColor);
        case 'wife': 
          return Image.asset('assets/icons/wife.png', width: 40, height: 40, color: iconColor);
        case 'standard':
          return Icon(Icons.room_service_rounded, size: 40, color: iconColor);
        case 'ramsay': 
          return Image.asset('assets/icons/chef.png', width: 40, height: 40, color: iconColor);
        default: 
          return Icon(Icons.flatware_rounded, size: 40, color: iconColor);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.person_pin_rounded, color: Colors.orange.shade400, size: 20),
            const SizedBox(width: 8),
            Text(
              lang.getText('style_section_title'), 
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Showcase.withWidget(
          key: showcaseKey,
          container: _CeiShowcaseBubble(
            title: lang.getText('showcase_2_title'), 
            description: lang.getText('showcase_2_desc'),
          ),
          child: SizedBox(
            height: 130,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: GenerationConstants.personas.entries.map((entry) {
                final key = entry.key;
                final data = entry.value;
                final minLevel = data['minLevel'] as int;
                final isLocked = userLevel < minLevel;
                final isSelected = selectedPersonaKey == key;
                
                final personaLangKey = 'persona_$key';
                String personaName = lang.getText(personaLangKey);
                if (personaName == personaLangKey) {
                    personaName = data['label'] ?? key;
                }

                return GestureDetector(
                  onTap: isLocked
                      ? () {
                          String msg = lang.getText('level_req');
                          msg = msg.replaceAll('@level', minLevel.toString())
                                   .replaceAll('@name', personaName);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                        }
                      : () => onSelect(key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 110,
                    margin: const EdgeInsets.only(right: 12, bottom: 4, top: 4),
                    decoration: BoxDecoration(
                      color: isLocked
                          ? Colors.grey.withOpacity(0.1)
                          : (isSelected ? Colors.orange.shade50 : Theme.of(context).cardColor),
                      border: Border.all(
                        color: isSelected ? Colors.orange : Colors.grey.withOpacity(0.2),
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isSelected 
                          ? [BoxShadow(color: Colors.orange.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))]
                          : [],
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              isLocked 
                                ? Icon(Icons.lock_outline_rounded, size: 32, color: Colors.grey.shade400)
                                : buildPersonaVisual(key, isSelected),

                              const SizedBox(height: 12),
                              Text(
                                personaName,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isLocked ? Colors.grey : (isSelected ? Colors.orange.shade800 : null),
                                ),
                              ),
                              if (isLocked)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    "${lang.getText('level_label')} $minLevel", 
                                    style: const TextStyle(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold)
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                              child: const Icon(Icons.check, size: 12, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// --- WIDGET 3: RECIPE SETTINGS (SHOWCASE 3 & 4) ---
class RecipeSettingsSection extends StatelessWidget {
  final GlobalKey cuisineKey;
  final GlobalKey optionsKey;
  final String selectedCountry;
  final String selectedRegion;
  final int selectedCount;
  final bool isOffline;
  final bool showRegionDropdown;
  final int userLevel; // Added userLevel
  final Function(String?) onCountryChanged;
  final Function(String?) onRegionChanged;
  final Function(int) onCountChanged;

  const RecipeSettingsSection({
    super.key,
    required this.cuisineKey,
    required this.optionsKey,
    required this.selectedCountry,
    required this.selectedRegion,
    required this.selectedCount,
    required this.isOffline,
    required this.showRegionDropdown,
    required this.userLevel, // Added userLevel
    required this.onCountryChanged,
    required this.onRegionChanged,
    required this.onCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    
    // Feature Locking Logic
    final bool isCountryUnlocked = userLevel >= 2;
    // final bool isCountUnlocked = userLevel >= 10; // Unused variable removed

    InputDecoration modernInputDecoration() {
      return InputDecoration(
        filled: true,
        fillColor: Theme.of(context).cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.orange, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SHOWCASE 3: FILTER NEGARA
        Showcase.withWidget(
          key: cuisineKey,
          container: _CeiShowcaseBubble(
            title: lang.getText('showcase_3_title'), 
            description: lang.getText('showcase_3_desc'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.public_rounded, size: 18, color: Colors.orange.shade400),
                  const SizedBox(width: 8),
                  Text(lang.getText('country_label'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  if (!isCountryUnlocked) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.lock, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    const Text("Lv. 2", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                  ]
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: !isCountryUnlocked ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Fitur ini terbuka di Level 2! Semangat masak! 🍳")),
                  );
                } : null,
                child: AbsorbPointer(
                  absorbing: !isCountryUnlocked,
                  child: Opacity(
                    opacity: isCountryUnlocked ? 1.0 : 0.5,
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
                        ]
                      ),
                      child: DropdownButtonFormField<String>(
                        value: selectedCountry,
                        items: GenerationConstants.countries.map((String country) {
                          String displayCountry = country;
                          if (country == 'Any') {
                              displayCountry = lang.getText('country_any'); 
                          }
                          
                          return DropdownMenuItem<String>(value: country, child: Text(displayCountry));
                        }).toList(),
                        onChanged: isOffline ? null : onCountryChanged,
                        decoration: modernInputDecoration(),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        dropdownColor: Theme.of(context).cardColor,
                      ),
                    ),
                  ),
                ),
              ),
              if (showRegionDropdown) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.map_rounded, size: 18, color: Colors.orange.shade400),
                    const SizedBox(width: 8),
                    Text(lang.getText('region_label'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
                    ]
                  ),
                  child: DropdownButtonFormField<String>(
                    value: selectedRegion,
                    items: GenerationConstants.regions["Indonesia"]!.map((String region) {
                      String displayRegion = region;
                      if (region == 'Any') displayRegion = lang.getText('country_any');

                      return DropdownMenuItem<String>(value: region, child: Text(displayRegion));
                    }).toList(),
                    onChanged: isOffline ? null : onRegionChanged,
                    decoration: modernInputDecoration(),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    dropdownColor: Theme.of(context).cardColor,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // SHOWCASE 4: JUMLAH
        Showcase.withWidget(
          key: optionsKey,
          container: _CeiShowcaseBubble(
            title: lang.getText('showcase_4_title'), 
            description: lang.getText('showcase_4_desc'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.format_list_numbered_rounded, size: 18, color: Colors.orange.shade400),
                  const SizedBox(width: 8),
                  Text(lang.getText('count_label'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: SegmentedButton<int>(
                                style: ButtonStyle(
                                  shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                  side: WidgetStateProperty.all(BorderSide(color: Colors.orange.withOpacity(0.5))),
                                  backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                    if (states.contains(WidgetState.selected)) {
                                      return Colors.orange.shade100;
                                    }
                                    return Theme.of(context).cardColor;
                                  }),
                                  foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                    if (states.contains(WidgetState.selected)) {
                                      return Colors.orange.shade900;
                                    }
                                    return Theme.of(context).textTheme.bodyMedium!.color!;
                                  }),
                                ),
                                segments: [
                                  ButtonSegment(
                                    value: 1, 
                                    label: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text("1"),
                                        Text(lang.getText('recipe_count_1'), style: const TextStyle(fontSize: 10)),
                                      ],
                                    ),
                                    enabled: !isOffline
                                  ),
                                  ButtonSegment(
                                    value: 3, 
                                    label: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (userLevel < 5) const Icon(Icons.lock, size: 16, color: Colors.grey) else const Text("3"),
                                        Text(userLevel < 5 ? "Lv. 5" : lang.getText('recipe_count_2'), style: const TextStyle(fontSize: 10)),
                                      ],
                                    ),
                                    enabled: !isOffline && userLevel >= 5
                                  ),
                                  ButtonSegment(
                                    value: 5, 
                                    label: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (userLevel < 10) const Icon(Icons.lock, size: 16, color: Colors.grey) else const Text("5"),
                                        Text(userLevel < 10 ? "Lv. 10" : lang.getText('recipe_count_3'), style: const TextStyle(fontSize: 10)),
                                      ],
                                    ),
                                    enabled: !isOffline && userLevel >= 10
                                  ),
                                  ButtonSegment(
                                    value: 10, 
                                    label: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (userLevel < 15) const Icon(Icons.lock, size: 16, color: Colors.grey) else const Text("10"),
                                        Text(userLevel < 15 ? "Lv. 15" : lang.getText('recipe_count_10'), style: const TextStyle(fontSize: 10)),
                                      ],
                                    ),
                                    enabled: !isOffline && userLevel >= 15
                                  ),
                                ],
                                selected: {selectedCount},
                                onSelectionChanged: isOffline ? null : (Set<int> newSelection) => onCountChanged(newSelection.first),
                              ),
                            ),
                          );
                        }
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- WIDGET 4: GENERATE BUTTON (SHOWCASE 5) ---
class GenerateButtonSection extends StatelessWidget {
  final GlobalKey showcaseKey;
  final bool isGenerating;
  final bool isOnCooldown;
  final bool isOffline;
  final int cooldownSeconds;
  final String personaLabel;
  final VoidCallback onPressed;

  const GenerateButtonSection({
    super.key,
    required this.showcaseKey,
    required this.isGenerating,
    required this.isOnCooldown,
    required this.isOffline,
    required this.cooldownSeconds,
    required this.personaLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    String buttonText = lang.getText('gen_btn_start'); // "Buat Resep"
    
    if (isOnCooldown) {
      buttonText = "${lang.getText('gen_btn_cooldown')} ($cooldownSeconds s)";
    } else if (isGenerating) {
      buttonText = lang.getText('gen_btn_loading'); // "Meracik Resep..."
    } else if (isOffline) {
      buttonText = lang.getText('gen_btn_offline');
    }

    return Showcase.withWidget(
      key: showcaseKey,
      targetShapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      targetPadding: const EdgeInsets.all(8), // FIX: Tambahkan padding agar button terlihat
      overlayOpacity: 0.7, // FIX: Kurangi opacity agar button lebih terlihat
      container: _CeiShowcaseBubble(
        title: lang.getText('showcase_5_title'), // "5. Eksekusi!"
        description: lang.getText('showcase_5_desc'),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: isGenerating
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Icon(isOffline ? Icons.wifi_off : Icons.auto_awesome),
          label: Text(buttonText),
          style: ElevatedButton.styleFrom(
            backgroundColor: isOffline ? Colors.grey : (isOnCooldown ? Colors.grey : Colors.orange),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: (isGenerating || isOnCooldown || isOffline) ? null : onPressed,
        ),
      ),
    );
  }
}

// --- WIDGET 5: NUTRITION INFO (NEW) ---
class NutritionInfoWidget extends StatelessWidget {
  final Map<String, String> nutrition;

  const NutritionInfoWidget({super.key, required this.nutrition});

  @override
  Widget build(BuildContext context) {
    // Panggil Provider Bahasa
    final lang = context.watch<LanguageProvider>();

    // Kalau datanya kosong atau strip semua, sembunyikan widget ini
    if (nutrition.isEmpty || nutrition.values.every((v) => v == '-')) {
      return const SizedBox.shrink();
    }

    // Trik: Kita pinjem key 'rd_share_nutrition' ("💪 *Info Nutrisi:*") 
    // tapi kita bersihin karakter emoji & bintangnya biar rapi jadi judul.
    final rawTitle = lang.getText('rd_share_nutrition');
    final cleanTitle = rawTitle.replaceAll(RegExp(r'[💪*:_]'), '').trim();

    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_heart_outlined, size: 18, color: Colors.orange[700]),
              const SizedBox(width: 6),
              Text(
                cleanTitle, // "Info Nutrisi" / "Nutrition Info"
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 12,
                  color: Colors.orange[800]
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Pake key dari provider (rd_share_calories, dll)
              _buildNutriItem(lang.getText('rd_share_calories'), nutrition['calories'] ?? '-', Colors.red),
              _buildVerticalDivider(),
              _buildNutriItem(lang.getText('rd_share_protein'), nutrition['protein'] ?? '-', Colors.deepOrange),
              _buildVerticalDivider(),
              _buildNutriItem(lang.getText('rd_share_carbs'), nutrition['carbs'] ?? '-', Colors.green),
              _buildVerticalDivider(),
              _buildNutriItem(lang.getText('rd_share_fat'), nutrition['fat'] ?? '-', Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 24,
      width: 1,
      color: Colors.grey.withOpacity(0.2),
    );
  }

  Widget _buildNutriItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800, 
            fontSize: 14,
            color: color
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    );
  }
}