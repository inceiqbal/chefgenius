import 'package:flutter/material.dart';
import '../../../app/data/models/recipe_model.dart';

/// Kartu konteks resep yang sedang dikonsultasikan oleh pengguna
class RecipeContextCard extends StatelessWidget {
  final Recipe recipe;
  final bool isDarkMode;

  const RecipeContextCard({
    super.key,
    required this.recipe,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/recipe-detail', arguments: recipe),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 40),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDarkMode
                ? [Colors.teal.shade800, Colors.teal.shade900]
                : [Colors.teal.shade50, Colors.white],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.teal.withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('🍳', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📋 Konsultasi Resep',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.teal[700],
                          ),
                        ),
                        Text(
                          recipe.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.teal.shade900,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Colors.teal[400]),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _buildRecipeInfo('⏱️', recipe.duration, isDarkMode),
                  _buildRecipeInfo('👥', recipe.servings, isDarkMode),
                  _buildRecipeInfo('📦', '${recipe.allIngredients.length} bahan', isDarkMode),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeInfo(String emoji, String text, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$emoji $text',
        style: TextStyle(
          fontSize: 11,
          color: isDarkMode ? Colors.teal[200] : Colors.teal[700],
        ),
      ),
    );
  }
}
