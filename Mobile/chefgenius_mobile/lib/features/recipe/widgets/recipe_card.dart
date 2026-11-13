import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/data/models/recipe_model.dart';
import '../screens/recipe_detail_screen.dart';
import '../../../app/config/chef_cei_assets.dart'; 
import '../../../app/data/providers/language_provider.dart';
import '../../../app/data/providers/recipe_rating_provider.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecipeRatingProvider>().loadRating(widget.recipe.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final lang = context.watch<LanguageProvider>();
    final isIndo = lang.appLocale.languageCode == 'id';
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final scorePercentage = (recipe.score * 100).toStringAsFixed(0);

    final ingredientsPreview = recipe.allIngredients
        .take(3) 
        .map((ingredient) => ingredient.name)
        .join(', ');
        
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
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RecipeDetailScreen(recipe: recipe),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- IMAGE SECTION ---
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: SizedBox(
                      width: double.infinity,
                      height: 160,
                      child: isAi
                          ? Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isDarkMode
                                      ? [const Color(0xFF2A2520), const Color(0xFF1E1A18)]
                                      : [Colors.orange.shade50, Colors.orange.shade100],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Center(
                                child: Image.asset(
                                  ChefCeiAssets.presentasi, 
                                  height: 100,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            )
                          : Hero(
                              tag: 'recipe_img_${recipe.id}',
                              child: recipe.imageUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: recipe.imageUrl,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: 160,
                                      placeholder: (context, url) => Container(
                                        color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                                      ),
                                      errorWidget: (context, url, error) => Image.asset(
                                        ChefCeiAssets.berhasil,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: 160,
                                      ),
                                    )
                                  : Image.asset(
                                      ChefCeiAssets.berhasil,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: 160,
                                    ),
                            ),
                    ),
                  ),
                  // Gradient overlay for better text readability
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.5),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Top badges row
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Row(
                      children: [
                        if (isAi)
                          _buildGradientBadge(
                            icon: Icons.auto_awesome_rounded,
                            label: "Chef Ceí AI",
                            gradient: const [Color(0xFFE67E22), Color(0xFFD35400)],
                          ),
                        if (recipe.score > 0) ...[
                          if (isAi) const SizedBox(width: 8),
                          _buildGradientBadge(
                            icon: Icons.verified_rounded,
                            label: "$scorePercentage% ${isIndo ? 'Cocok' : 'Match'}",
                            gradient: const [Color(0xFF27AE60), Color(0xFF1E8449)],
                          ),
                        ],
                        const Spacer(),
                        // Rating badge
                        if (!isAi)
                          Consumer<RecipeRatingProvider>(
                            builder: (context, ratingProvider, child) {
                              final avgRating = ratingProvider.getAverageRating(recipe.id);
                              final ratingCount = ratingProvider.getRatingCount(recipe.id);
                              
                              if (avgRating > 0) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                                      const SizedBox(width: 4),
                                      Text(
                                        avgRating.toStringAsFixed(1),
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      if (ratingCount > 0) ...[
                                        Text(
                                          ' ($ratingCount)',
                                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10),
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
                  ),
                  // Halal badge at bottom
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: (isHalal ? Colors.green : Colors.red).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isHalal ? Icons.check_circle_rounded : Icons.warning_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            recipe.halalStatus,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              // --- CONTENT SECTION ---
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      recipe.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDarkMode ? Colors.white : Colors.black87,
                        height: 1.3,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    // Ingredients preview
                    if (ingredientsText.isNotEmpty && !isAi) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.restaurant_menu_rounded, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              ingredientsText,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Nutrition widget
                    if (recipe.nutrition != null) ...[
                      const SizedBox(height: 12),
                      NutritionInfoWidget(nutrition: recipe.nutrition),
                    ],

                    const SizedBox(height: 12),
                    
                    // Footer meta info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (hasDuration)
                            Flexible(
                              child: _buildModernMetaItem(
                                icon: Icons.schedule_rounded,
                                label: recipe.duration,
                                color: Colors.orange,
                                isDarkMode: isDarkMode,
                              ),
                            ),
                          if (hasDuration && hasServings)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Container(
                                height: 24,
                                width: 1,
                                color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                              ),
                            ),
                          if (hasServings)
                            Flexible(
                              child: _buildModernMetaItem(
                                icon: Icons.people_alt_rounded,
                                label: "${recipe.servings} ${lang.getText('rd_servings')}",
                                color: Colors.blue,
                                isDarkMode: isDarkMode,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradientBadge({
    required IconData icon,
    required String label,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernMetaItem({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDarkMode,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}