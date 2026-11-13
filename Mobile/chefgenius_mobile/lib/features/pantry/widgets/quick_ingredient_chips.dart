import 'package:flutter/material.dart';

class QuickIngredientChips extends StatelessWidget {
  final List<String> ingredients;
  final bool isOffline;
  final bool isAdding;
  final Function(String) onAdd;

  const QuickIngredientChips({
    super.key,
    required this.ingredients,
    required this.isOffline,
    required this.isAdding,
    required this.onAdd,
  });

  // Get emoji for common ingredients
  String _getEmoji(String ingredient) {
    final lower = ingredient.toLowerCase();
    if (lower.contains('telur')) return '🥚';
    if (lower.contains('ayam')) return '🍗';
    if (lower.contains('nasi') || lower.contains('beras')) return '🍚';
    if (lower.contains('bawang')) return '🧅';
    if (lower.contains('cabai') || lower.contains('cabe')) return '🌶️';
    if (lower.contains('tahu')) return '🧈';
    if (lower.contains('tempe')) return '🫘';
    if (lower.contains('kecap')) return '🫗';
    if (lower.contains('susu')) return '🥛';
    if (lower.contains('roti')) return '🍞';
    return '➕';
  }

  @override
  Widget build(BuildContext context) {
    if (isOffline) return const SizedBox.shrink();
    
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.flash_on_rounded,
                size: 18,
                color: Colors.amber.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                'Tambah Cepat',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: ingredients.length,
            itemBuilder: (context, index) {
              final item = ingredients[index];
              final emoji = _getEmoji(item);
              
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: isAdding ? null : () => onAdd(item),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDarkMode
                              ? [const Color(0xFF2A2A3E), const Color(0xFF1E1E2E)]
                              : [Colors.white, const Color(0xFFFFFAF5)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDarkMode 
                              ? Colors.grey.shade800 
                              : Colors.orange.withOpacity(0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            item,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}