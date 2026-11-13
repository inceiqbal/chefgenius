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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.kitchen_rounded, color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.getText('your_fridge'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (hasItems)
                    Text(
                      'Geser ke kiri untuk hapus',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (!isLoading && hasItems && !isOffline)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: onClearAll,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_sweep_rounded, size: 16, color: Colors.red.shade400),
                      const SizedBox(width: 4),
                      Text(
                        lang.getText('delete_all'),
                        style: TextStyle(
                          color: Colors.red.shade400,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
