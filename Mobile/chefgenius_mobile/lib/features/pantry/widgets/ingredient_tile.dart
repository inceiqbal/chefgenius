import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/widgets/modern_alert_dialog.dart';
import '../../../app/data/providers/language_provider.dart';

class IngredientTile extends StatelessWidget {
  final String name;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const IngredientTile({
    super.key, 
    required this.name, 
    required this.onDelete,
    required this.onEdit,
  });

  // Get emoji based on ingredient name
  String _getIngredientEmoji(String ingredient) {
    final lower = ingredient.toLowerCase();
    
    // Proteins
    if (lower.contains('ayam') || lower.contains('chicken')) return '🍗';
    if (lower.contains('daging') || lower.contains('sapi') || lower.contains('beef')) return '🥩';
    if (lower.contains('ikan') || lower.contains('fish')) return '🐟';
    if (lower.contains('udang') || lower.contains('shrimp')) return '🦐';
    if (lower.contains('telur') || lower.contains('egg')) return '🥚';
    if (lower.contains('tahu') || lower.contains('tofu')) return '🧈';
    if (lower.contains('tempe')) return '🫘';
    
    // Vegetables
    if (lower.contains('bawang') && lower.contains('merah')) return '🧅';
    if (lower.contains('bawang') && lower.contains('putih')) return '🧄';
    if (lower.contains('bawang')) return '🧅';
    if (lower.contains('wortel') || lower.contains('carrot')) return '🥕';
    if (lower.contains('tomat') || lower.contains('tomato')) return '🍅';
    if (lower.contains('cabai') || lower.contains('cabe') || lower.contains('chili')) return '🌶️';
    if (lower.contains('paprika') || lower.contains('pepper')) return '🫑';
    if (lower.contains('kentang') || lower.contains('potato')) return '🥔';
    if (lower.contains('jagung') || lower.contains('corn')) return '🌽';
    if (lower.contains('brokoli') || lower.contains('broccoli')) return '🥦';
    if (lower.contains('selada') || lower.contains('lettuce')) return '🥬';
    if (lower.contains('bayam') || lower.contains('spinach')) return '🥬';
    if (lower.contains('jamur') || lower.contains('mushroom')) return '🍄';
    if (lower.contains('terong') || lower.contains('eggplant')) return '🍆';
    if (lower.contains('timun') || lower.contains('cucumber')) return '🥒';
    
    // Fruits
    if (lower.contains('apel') || lower.contains('apple')) return '🍎';
    if (lower.contains('pisang') || lower.contains('banana')) return '🍌';
    if (lower.contains('jeruk') || lower.contains('orange')) return '🍊';
    if (lower.contains('anggur') || lower.contains('grape')) return '🍇';
    if (lower.contains('semangka') || lower.contains('watermelon')) return '🍉';
    if (lower.contains('melon')) return '🍈';
    if (lower.contains('mangga') || lower.contains('mango')) return '🥭';
    if (lower.contains('nanas') || lower.contains('pineapple')) return '🍍';
    if (lower.contains('stroberi') || lower.contains('strawberry')) return '🍓';
    if (lower.contains('lemon')) return '🍋';
    if (lower.contains('alpukat') || lower.contains('avocado')) return '🥑';
    if (lower.contains('kelapa') || lower.contains('coconut')) return '🥥';
    
    // Grains & Carbs
    if (lower.contains('nasi') || lower.contains('beras') || lower.contains('rice')) return '🍚';
    if (lower.contains('mie') || lower.contains('noodle')) return '🍜';
    if (lower.contains('roti') || lower.contains('bread')) return '🍞';
    if (lower.contains('pasta') || lower.contains('spaghetti')) return '🍝';
    
    // Dairy
    if (lower.contains('susu') || lower.contains('milk')) return '🥛';
    if (lower.contains('keju') || lower.contains('cheese')) return '🧀';
    if (lower.contains('mentega') || lower.contains('butter')) return '🧈';
    if (lower.contains('yogurt')) return '🥛';
    
    // Condiments
    if (lower.contains('kecap') || lower.contains('soy sauce')) return '🫗';
    if (lower.contains('garam') || lower.contains('salt')) return '🧂';
    if (lower.contains('gula') || lower.contains('sugar')) return '🍬';
    if (lower.contains('minyak') || lower.contains('oil')) return '🫒';
    if (lower.contains('madu') || lower.contains('honey')) return '🍯';
    
    // Default
    return '🥘';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Parse name and quantity from "name|quantity" format
    final parts = name.split('|');
    final ingredientName = parts[0];
    final quantity = parts.length > 1 ? parts[1] : '';
    final emoji = _getIngredientEmoji(ingredientName);
    
    return Dismissible(
      key: Key(name),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade400, Colors.red.shade600],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Icon(Icons.delete_forever, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Text(context.read<LanguageProvider>().getText('delete_btn'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        final lang = context.read<LanguageProvider>();
        return await ModernAlertDialog.showConfirmation(
          context: context,
          title: lang.getText('delete_ingredient_title'),
          message: lang.getText('delete_ingredient_msg').replaceAll('@name', ingredientName),
          confirmText: lang.getText('delete_btn'),
          cancelText: lang.getText('cancel'),
          icon: Icons.delete_forever_rounded,
          isDestructive: true,
        );
      },
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDarkMode 
                ? [const Color(0xFF2A2A3E), const Color(0xFF1E1E2E)]
                : [Colors.white, const Color(0xFFFFFAF5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDarkMode 
                  ? Colors.black.withOpacity(0.15) 
                  : Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: isDarkMode ? Colors.grey.shade800 : Colors.orange.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Emoji Avatar
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDarkMode
                            // Softer warm tones for dark mode
                            ? [const Color(0xFF92400E), const Color(0xFF78350F)]
                            : [const Color(0xFFFEF3C7), const Color(0xFFFDE68A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Name and Quantity
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ingredientName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (quantity.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              quantity,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode ? Colors.orange.shade200 : Colors.orange.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Actions
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Edit Button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.edit_rounded,
                            color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade600,
                            size: 20,
                          ),
                          onPressed: onEdit,
                          tooltip: "Edit",
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Swipe hint
                      Icon(
                        Icons.chevron_left_rounded,
                        color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}