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

  @override
  Widget build(BuildContext context) {
    if (isOffline) return const SizedBox.shrink();

    return Container(
      height: 50,
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: ingredients.length,
        itemBuilder: (context, index) {
          final item = ingredients[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              label: Text(item),
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              side: BorderSide.none,
              onPressed: isAdding ? null : () => onAdd(item),
            ),
          );
        },
      ),
    );
  }
}