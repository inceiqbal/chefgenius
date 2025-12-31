import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../app/data/models/recipe_model.dart';
import '../../../app/data/utils/ingredient_matcher.dart';
import '../../../app/data/providers/language_provider.dart';

class RecipeIngredientsList extends StatelessWidget {
  final Recipe recipe;
  final Map<String, IngredientMatchStatus> ingredientStatuses;
  final bool isCheckingStock;
  final int missingCount;
  final bool isAddingToCart;
  final VoidCallback onAddMissingToCart;
  final VoidCallback onCopyIngredients;

  const RecipeIngredientsList({
    super.key,
    required this.recipe,
    required this.ingredientStatuses,
    required this.isCheckingStock,
    required this.missingCount,
    required this.isAddingToCart,
    required this.onAddMissingToCart,
    required this.onCopyIngredients,
  });

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final brightGreen = isDarkMode ? Colors.lightGreenAccent : Colors.green;
    final warningColor = Colors.orange;

    if (recipe.allIngredients.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              lang.getText('rd_ingredients'), 
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            IconButton(
              onPressed: onCopyIngredients, 
              icon: const Icon(Icons.copy_rounded, size: 20),
              tooltip: lang.getText('rd_copy_tooltip'), 
            )
          ],
        ),
        const SizedBox(height: 12),

        if (isCheckingStock)
            const Center(child: Padding(padding: EdgeInsets.all(8.0), child: LinearProgressIndicator()))
        else ...[
            if (missingCount > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50, 
                  borderRadius: BorderRadius.circular(16), 
                  border: Border.all(color: Colors.red.shade100)
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shopping_cart_checkout_rounded, color: Colors.red.shade700, size: 20), 
                        const SizedBox(width: 8), 
                        Text(lang.getText('rd_missing_title'), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900)) 
                      ]
                    ),
                    const SizedBox(height: 8),
                    Text(lang.getText('rd_missing_desc').replaceAll('@count', '$missingCount'), style: TextStyle(fontSize: 13, color: Colors.red.shade800)), 
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isAddingToCart ? null : onAddMissingToCart,
                        icon: isAddingToCart 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.add_shopping_cart_rounded, size: 18),
                        label: Text(isAddingToCart ? lang.getText('rd_btn_saving') : lang.getText('rd_btn_add_cart')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent, 
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                        ),
                      ),
                    )
                  ],
                ),
              ),
        ],

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: recipe.allIngredients
              .map((ingredient) {
                final status = ingredientStatuses[ingredient.name] ?? IngredientMatchStatus.missing;
                
                Color itemColor;
                IconData statusIcon;
                Color statusColor;
                String statusText;

                switch (status) {
                  case IngredientMatchStatus.full:
                    itemColor = brightGreen;
                    statusIcon = Icons.check_circle;
                    statusColor = brightGreen;
                    statusText = lang.getText('rd_status_full'); 
                    break;
                  case IngredientMatchStatus.partial:
                    itemColor = warningColor;
                    statusIcon = Icons.warning_rounded;
                    statusColor = warningColor;
                    statusText = lang.getText('rd_status_partial'); 
                    break;
                  case IngredientMatchStatus.missing:
                    itemColor = isDarkMode ? Colors.white70 : Colors.black87;
                    statusIcon = Icons.cancel_outlined;
                    statusColor = Colors.redAccent;
                    statusText = lang.getText('rd_status_missing'); 
                    break;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        statusIcon,
                        size: 20,
                        color: statusColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${ingredient.quantity} ${ingredient.name}'.trim(),
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: itemColor, 
                            fontWeight: status != IngredientMatchStatus.missing ? FontWeight.bold : FontWeight.normal
                          ),
                        ),
                      ),
                      Text(
                        statusText, 
                        style: TextStyle(fontSize: 10, color: statusColor, fontStyle: FontStyle.italic)
                      )
                    ],
                  ),
                );
              })
              .toList(),
        ),
        const Divider(height: 24),
      ],
    );
  }
}
