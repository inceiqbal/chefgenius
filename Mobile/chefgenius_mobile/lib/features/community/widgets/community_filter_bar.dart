import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/community_provider.dart';

class CommunityFilterBar extends StatelessWidget {
  const CommunityFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<CommunityProvider>();
    
    final List<String> categories = ['Semua', 'Makanan', 'Minuman', 'Set Menu', 'Hasil Resep ChefGenius'];
    final List<String> sortOptions = ['Terbaru', 'Like Terbanyak', 'Populer'];

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Filter Kategori
          ...categories.map((category) {
            final isSelected = provider.selectedCategory == category;
            IconData icon;
            switch (category) {
              case 'Makanan': icon = Icons.restaurant_rounded; break;
              case 'Minuman': icon = Icons.local_cafe_rounded; break;
              case 'Set Menu': icon = Icons.restaurant_menu_rounded; break;
              case 'Hasil Resep ChefGenius': icon = Icons.auto_awesome_rounded; break;
              default: icon = Icons.grid_view_rounded;
            }

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(
                  icon, 
                  size: 18, 
                  color: isSelected 
                      ? Colors.orange.shade900 
                      : (isDarkMode ? Colors.white70 : Colors.grey[600])
                ),
                label: Text(category),
                selected: isSelected,
                selectedColor: Colors.orange.shade100,
                backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                labelStyle: TextStyle(
                  color: isSelected 
                      ? Colors.orange.shade900 
                      : (isDarkMode ? Colors.white : Colors.black87),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (selected) {
                  if (selected) {
                    context.read<CommunityProvider>().setCategory(category);
                  }
                },
              ),
            );
          }),
          // Sort Options
          DropdownButton<String>(
            value: provider.selectedSort,
            underline: const SizedBox(),
            icon: const Icon(Icons.sort, color: Colors.orange),
            dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontSize: 14,
            ),
            items: sortOptions.map((String sort) {
              return DropdownMenuItem<String>(
                value: sort,
                child: Text(sort),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                context.read<CommunityProvider>().setSort(newValue);
              }
            },
          ),
        ],
      ),
    );
  }
}
