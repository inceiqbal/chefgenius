import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../app/data/models/recipe_model.dart';
import '../screens/recipe_detail_screen.dart';
import '../../../app/config/chef_cei_assets.dart'; // IMPORT ASET CHEF CEI

class RecipeCard extends StatelessWidget {
  final Recipe recipe;

  const RecipeCard({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    // Format Score jadi persen
    final scorePercentage = (recipe.score * 100).toStringAsFixed(0);

    // Ambil 3 bahan pertama aja buat preview biar gak kepanjangan
    final ingredientsPreview = recipe.allIngredients
        .take(3) 
        .map((ingredient) => ingredient.name)
        .join(', ');
        
    final String ingredientsText = recipe.allIngredients.length > 3 
        ? "$ingredientsPreview, +${recipe.allIngredients.length - 3} lainnya"
        : ingredientsPreview;

    final bool isHalal = recipe.halalStatus.toLowerCase() == 'halal';
    final bool isAi = recipe.isAiGenerated;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RecipeDetailScreen(recipe: recipe),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- HEADER: GAMBAR & JUDUL ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // GAMBAR (LOGIKA BARU)
                    if (!isAi && recipe.imageUrl.isNotEmpty)
                      // 1. Resep Biasa: Pake Gambar URL
                      Hero(
                        tag: 'recipe_img_${recipe.id}', 
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: recipe.imageUrl,
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.image, color: Colors.grey),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.broken_image, color: Colors.grey),
                            ),
                          ),
                        ),
                      )
                    else if (isAi)
                      // 2. Resep AI: PAKE VISUAL CHEF CEI (Ganti Ikon Biru)
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50, // Background tipis biar gambar pop
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            ChefCeiAssets.presentasi, // Pake pose Presentasi
                            fit: BoxFit.cover, // Atau BoxFit.contain tergantung selera
                          ),
                        ),
                      )
                    else
                      // 3. Fallback: Placeholder biasa
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.restaurant, color: Colors.orange),
                      ),

                    const SizedBox(width: 12),

                    // Judul & Badge (Kanan)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badge AI / Cocok
                          Row(
                            children: [
                              if (isAi)
                                Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [Colors.blue, Colors.lightBlueAccent]),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    "Chef Cei",
                                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              
                              if (recipe.score > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.verified, size: 10, color: Colors.green),
                                      const SizedBox(width: 4),
                                      Text(
                                        "$scorePercentage% Cocok",
                                        style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          
                          const SizedBox(height: 6),

                          Text(
                            recipe.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          if (ingredientsText.isNotEmpty && !isAi) ...[
                             const SizedBox(height: 6),
                             Text(
                               ingredientsText,
                               style: TextStyle(color: Colors.grey[600], fontSize: 11),
                               maxLines: 1,
                               overflow: TextOverflow.ellipsis,
                             ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 12),

                // --- FOOTER: INFO DETIL (Desain Baru) ---
                // Dibuat Row biar rapi sejajar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // 1. Durasi
                    _buildMetaItem(
                      Icons.access_time_rounded, 
                      recipe.duration.isNotEmpty ? recipe.duration : 'N/A',
                      Colors.orange
                    ),
                    
                    _buildDivider(),

                    // 2. Porsi
                    _buildMetaItem(
                      Icons.people_alt_rounded, 
                      recipe.servings.isNotEmpty ? "${recipe.servings} Porsi" : 'N/A',
                      Colors.blue
                    ),

                    _buildDivider(),

                    // 3. Halal Status
                    _buildMetaItem(
                      isHalal ? Icons.check_circle_rounded : Icons.warning_rounded, 
                      recipe.halalStatus,
                      isHalal ? Colors.green : Colors.red
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 16,
      width: 1,
      color: Colors.grey.withOpacity(0.3),
    );
  }

  Widget _buildMetaItem(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Container(
          constraints: const BoxConstraints(maxWidth: 70), // Biar gak overflow kalo teks panjang
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11, 
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.8),
              overflow: TextOverflow.ellipsis
            ),
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}