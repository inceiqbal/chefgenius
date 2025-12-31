import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/data/providers/language_provider.dart';

class PantrySearchButton extends StatelessWidget {
  final bool isSearching;
  final bool isOffline;
  final bool isLoading;
  final VoidCallback onSearch;

  const PantrySearchButton({
    super.key,
    required this.isSearching,
    required this.isOffline,
    required this.isLoading,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ElevatedButton.icon(
        icon: isSearching
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(isOffline ? Icons.wifi_off : Icons.menu_book),
        label: Text(isSearching 
            ? lang.getText('search_recipe_loading') 
            : isOffline ? lang.getText('offline_mode') : lang.getText('search_recipe_btn')),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          minimumSize: const Size(double.infinity, 50),
          backgroundColor: isOffline 
              ? (isDarkMode ? Colors.grey[800] : Colors.grey) 
              : (isDarkMode ? Colors.orange[800] : Colors.orange), 
          foregroundColor: Colors.white,
          elevation: isDarkMode ? 2 : 4,
          shadowColor: isDarkMode ? Colors.white24 : Colors.black26,
        ),
        onPressed: isLoading || isSearching || isOffline ? null : onSearch,
      ),
    );
  }
}
