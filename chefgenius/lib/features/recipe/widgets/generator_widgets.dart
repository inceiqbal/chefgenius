import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../../app/data/utils/generation_constants.dart'; // Import Constants dari Utils

// --- WIDGET 1: PERSONA SELECTOR ---
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
    if (isOffline) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pilih Gaya Chef (Hadiah Level):',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 10),
        Showcase(
          key: showcaseKey,
          title: '2. Pilih Gaya Chef',
          description: 'Capai level tertentu untuk membuka gaya koki yang unik.',
          child: SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: GenerationConstants.personas.entries.map((entry) {
                final key = entry.key;
                final data = entry.value;
                final minLevel = data['minLevel'] as int;
                final isLocked = userLevel < minLevel;
                final isSelected = selectedPersonaKey == key;

                return GestureDetector(
                  onTap: isLocked
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Capai Level $minLevel dulu buat buka ${data['label']}!")),
                          );
                        }
                      : () => onSelect(key),
                  child: Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isLocked
                          ? Colors.grey.withOpacity(0.2)
                          : (isSelected ? Colors.blue.withOpacity(0.1) : Theme.of(context).cardColor),
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.3),
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isLocked ? Icons.lock : data['icon'],
                          color: isLocked ? Colors.grey : (isSelected ? Colors.blue : Colors.grey[700]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data['label'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isLocked ? Colors.grey : null,
                          ),
                        ),
                        if (isLocked)
                          Text("Lv $minLevel", style: const TextStyle(fontSize: 10, color: Colors.red)),
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

// --- WIDGET 2: RECIPE SETTINGS (Negara & Jumlah) ---
class RecipeSettingsSection extends StatelessWidget {
  final GlobalKey cuisineKey;
  final GlobalKey optionsKey;
  final String selectedCountry;
  final String selectedRegion;
  final int selectedCount;
  final bool isOffline;
  final bool showRegionDropdown;
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
    required this.onCountryChanged,
    required this.onRegionChanged,
    required this.onCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    final subtitleStyle = TextStyle(
      fontSize: 10, // Kecilin dikit biar muat 4 tombol
      fontWeight: FontWeight.normal,
      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // FILTER NEGARA
        Showcase(
          key: cuisineKey,
          title: '3. Filter Resep',
          description: 'Anda bisa memfilter resep berdasarkan negara atau daerah.',
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: selectedCountry,
                items: GenerationConstants.countries.map((String country) {
                  return DropdownMenuItem<String>(value: country, child: Text(country));
                }).toList(),
                onChanged: isOffline ? null : onCountryChanged,
                decoration: const InputDecoration(
                    labelText: 'Negara', 
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                ),
              ),
              if (showRegionDropdown) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRegion,
                  items: GenerationConstants.regions["Indonesia"]!.map((String region) {
                    return DropdownMenuItem<String>(value: region, child: Text(region));
                  }).toList(),
                  onChanged: isOffline ? null : onRegionChanged,
                  decoration: const InputDecoration(
                    labelText: 'Daerah di Indonesia', 
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // PILIH JUMLAH
        Showcase(
          key: optionsKey,
          title: '4. Pilih Jumlah Resep',
          description: 'Mau dibikinin berapa resep? Kuota pakenya sama aja kok!',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mau dibuatkan berapa resep?', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Kalo layar kekecilan, pake Wrap atau ScrollView biar gak overflow
                    // Tapi SegmentedButton biasanya responsive
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: SegmentedButton<int>(
                          segments: [
                            ButtonSegment(value: 1, label: Column(children: [const Text('1'), Text('(~5s)', style: subtitleStyle)]), enabled: !isOffline),
                            ButtonSegment(value: 3, label: Column(children: [const Text('3'), Text('(~10s)', style: subtitleStyle)]), enabled: !isOffline),
                            ButtonSegment(value: 5, label: Column(children: [const Text('5'), Text('(~15s)', style: subtitleStyle)]), enabled: !isOffline),
                            // --- OPSI 10 RESEP (DITAMBAHKAN) ---
                            ButtonSegment(value: 10, label: Column(children: [const Text('10'), Text('(~30s)', style: subtitleStyle)]), enabled: !isOffline),
                          ],
                          selected: {selectedCount},
                          onSelectionChanged: isOffline ? null : (Set<int> newSelection) => onCountChanged(newSelection.first),
                          style: SegmentedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
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