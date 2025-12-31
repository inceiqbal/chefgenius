import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/data/providers/language_provider.dart';

class PantryHeader extends StatelessWidget {
  final bool isLoading;
  final bool hasItems;
  final bool isOffline;
  final VoidCallback onClearAll;

  const PantryHeader({
    super.key,
    required this.isLoading,
    required this.hasItems,
    required this.isOffline,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            lang.getText('your_fridge'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
            ),
          ),
          if (!isLoading && hasItems && !isOffline)
            TextButton.icon(
              onPressed: onClearAll,
              icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.redAccent),
              label: Text(lang.getText('delete_all'), style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }
}
