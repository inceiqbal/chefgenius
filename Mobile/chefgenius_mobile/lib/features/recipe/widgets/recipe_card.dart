import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Jangan lupa import Provider
import '../../../app/data/models/recipe_model.dart';
import '../screens/recipe_detail_screen.dart';
import '../../../app/config/chef_cei_assets.dart'; 
import '../../../app/data/providers/language_provider.dart'; // Import LanguageProvider
import '../../../app/data/providers/recipe_rating_provider.dart'; // Import Rating Provider

// PERBAIKAN: Import file widget yang bener (karena NutritionInfoWidget udah pindah ke sini)
import 'generator_widgets.dart'; 

class RecipeCard extends StatefulWidget {
  final Recipe recipe;

  const RecipeCard({super.key, required this.recipe});

  @override
  State<RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<RecipeCard> {
  @override
  void initState() {
    super.initState();
    // Load rating for this recipe
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecipeRatingProvider>().loadRating(widget.recipe.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    
    // 1. PANGGIL PROVIDER BAHASA
    final lang = context.watch<LanguageProvider>();
    final isIndo = lang.appLocale.languageCode == 'id'; // Cek bahasa aktif

    final scorePercentage = (recipe.score * 100).toStringAsFixed(0);

    final ingredientsPreview = recipe.allIngredients
        .take(3) 
        .map((ingredient) => ingredient.name)
        .join(', ');
        
    // 2. TERJEMAHAN MANUAL: "Lainnya" vs "More"
    final String moreText = isIndo ? "lainnya" : "more";
    final String ingredientsText = recipe.allIngredients.length > 3 
        ? "$ingredientsPreview, +${recipe.allIngredients.length - 3} $moreText"
        : ingredientsPreview;

    final bool isHalal = recipe.halalStatus.toLowerCase() == 'halal';
    final bool isAi = recipe.isAiGenerated;
    
    final bool hasDuration = recipe.duration.isNotEmpty;
    final bool hasServings = recipe.servings.isNotEmpty;

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
                    // GAMBAR
                    if (!isAi)
                      Hero(
                        tag: 'recipe_img_${recipe.id}', 
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: recipe.imageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: recipe.imageUrl,
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(color: Colors.grey[200]),
                                  errorWidget: (context, url, error) => Image.asset(
                                    ChefCeiAssets.berhasil,
                                    width: 90,
                                    height: 90,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Image.asset(
                                  ChefCeiAssets.berhasil,
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      )
                    else
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            ChefCeiAssets.presentasi, 
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                    const SizedBox(width: 12),

                    // Judul & Badge
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
                                  child: const Text("Chef Cei", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
                                        "$scorePercentage% ${isIndo ? 'Cocok' : 'Match'}", 
                                        style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)
                                      ),
                                    ],
                                  ),
                                ),
                              
                              // Rating badge for non-AI recipes
                              if (!isAi)
                                Consumer<RecipeRatingProvider>(
                                  builder: (context, ratingProvider, child) {
                                    final avgRating = ratingProvider.getAverageRating(recipe.id);
                                    final ratingCount = ratingProvider.getRatingCount(recipe.id);
                                    
                                    if (avgRating > 0) {
                                      return Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.amber.withOpacity(0.4)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                                            const SizedBox(width: 2),
                                            Text(
                                              avgRating.toStringAsFixed(1),
                                              style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                            if (ratingCount > 0) ...[
                                              const SizedBox(width: 2),
                                              Text(
                                                '($ratingCount)',
                                                style: TextStyle(color: Colors.amber.shade700, fontSize: 9),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
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

                // --- WIDGET NUTRISI BARU (Import dari generator_widgets.dart) ---
                NutritionInfoWidget(nutrition: recipe.nutrition),
                // ----------------------------------

                const SizedBox(height: 8),
                const Divider(height: 1, thickness: 0.5),
                const SizedBox(height: 8),

                // --- FOOTER INFO ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround, 
                  children: [
                    if (hasDuration) ...[
                      _buildMetaItem(Icons.access_time_rounded, recipe.duration, Colors.orange),
                      _buildDivider(),
                    ],

                    if (hasServings) ...[
                      // 4. TERJEMAHAN: Pake key 'rd_servings' ("Porsi" / "Servings") dari kamus
                      _buildMetaItem(Icons.people_alt_rounded, "${recipe.servings} ${lang.getText('rd_servings')}", Colors.blue),
                      _buildDivider(),
                    ],

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
          constraints: const BoxConstraints(maxWidth: 80), 
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