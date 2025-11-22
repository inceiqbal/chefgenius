import 'package:flutter/material.dart';

class IngredientTile extends StatelessWidget {
  final String name;
  final VoidCallback onDelete;

  const IngredientTile({super.key, required this.name, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Row(
          children: [
            const Icon(Icons.restaurant_menu, color: Colors.deepOrange, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(name, style: const TextStyle(fontSize: 16))),
            IconButton(icon: Icon(Icons.close, color: Colors.grey[600], size: 20), onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}