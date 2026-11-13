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
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.7),
        border: Border(
          bottom: BorderSide(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
            width: 0.5,
          ),
        ),
      ),
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
              child: GestureDetector(
                onTap: () => context.read<CommunityProvider>().setCategory(category),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [Color(0xFFE67E22), Color(0xFFD35400)],
                          )
                        : null,
                    color: isSelected ? null : (isDarkMode ? Colors.grey[850] : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected
                        ? null
                        : Border.all(
                            color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                            width: 0.5,
                          ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFFE67E22).withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 16,
                        color: isSelected
                            ? Colors.white
                            : (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        category == 'Hasil Resep ChefGenius' ? 'Hasil AI' : category,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          // Sort Options
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[850] : Colors.grey[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                width: 0.5,
              ),
            ),
            child: DropdownButton<String>(
              value: provider.selectedSort,
              underline: const SizedBox(),
              icon: const Icon(Icons.sort_rounded, color: Colors.orange, size: 18),
              dropdownColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              style: TextStyle(
                color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                fontSize: 13,
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
          ),
        ],
      ),
    );
  }
}
