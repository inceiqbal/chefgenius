import 'package:flutter/material.dart';

class IngredientTile extends StatelessWidget {
  final String name;
  final VoidCallback onDelete;

  const IngredientTile({super.key, required this.name, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black12 : Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: isDarkMode ? Colors.grey[800]! : Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.orange.withOpacity(0.2) : Colors.orange.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.restaurant_menu_rounded, color: isDarkMode ? Colors.orange[300] : Colors.orange.shade700, size: 20),
        ),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
          onPressed: onDelete,
          tooltip: "Hapus",
        ),
      ),
    );
  }
}