import 'package:chefgenius/app/data/models/ingredient_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../app/data/models/recipe_model.dart';
import '../widgets/recipe_card.dart';
import '../screens/recipe_detail_screen.dart';
import '../../../app/data/providers/connectivity_provider.dart';
import '../../../app/data/providers/language_provider.dart';
import '../../../app/widgets/offline_banner.dart';

class FavoriteRecipesScreen extends StatefulWidget {
  const FavoriteRecipesScreen({super.key});

  @override
  State<FavoriteRecipesScreen> createState() => _FavoriteRecipesScreenState();
}

class _FavoriteRecipesScreenState extends State<FavoriteRecipesScreen> {
  late Future<List<Recipe>> _allFavoriteRecipesFuture;
  final supabase = Supabase.instance.client;

  static const String _favCacheBoxName = 'favorite_recipes_cache';

  @override
  void initState() {
    super.initState();
    _allFavoriteRecipesFuture = _loadAllFavoriteRecipes();
  }

  Future<List<Recipe>> _loadAllFavoriteRecipes() async {
    final connectivityProvider = context.read<ConnectivityProvider>();
    final favBox = await Hive.openBox<Recipe>(_favCacheBoxName);

    if (connectivityProvider.isOffline) {
      debugPrint("--- OFFLINE MODE: Muat favorit dari cache Hive ---");
      return favBox.values.toList();
    }

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final List<Recipe> normalFavorites = [];
      final List<Recipe> aiFavorites = [];

      final List<dynamic> idData = await supabase
          .from('favorite_recipes')
          .select('recipe_id')
          .eq('user_id', userId);

      if (idData.isNotEmpty) {
        final List<int> favoriteRecipeIds =
            idData.map((fav) => fav['recipe_id'] as int).toList();

        final List<dynamic> recipeData = await supabase
            .from('recipes')
            .select('*')
            .filter('id', 'in', favoriteRecipeIds);

        final List<Recipe> foundNormalFavorites = recipeData.map((json) {
          final recipe = Recipe.fromJson(json, isGeneratedByAi: false);

          final String dbImageUrl = json['image_url'] ?? '';
          if (dbImageUrl.isNotEmpty) {
            final String filename = dbImageUrl.split('/').last;
            recipe.imageUrl = supabase.storage
                .from('recipe-images')
                .getPublicUrl('Food Images/$filename');
          }

          recipe.isFavorite = true;
          return recipe;
        }).toList();

        normalFavorites.addAll(foundNormalFavorites);
      }

      final List<dynamic> aiData = await supabase
          .from('ai_favorite_recipes')
          .select(
              'id, title, ingredients, steps, image_url, duration, servings, halal_status')
          .eq('user_id', userId);

      if (aiData.isNotEmpty) {
        for (var data in aiData) {
          try {
            final List<Ingredient> ingredients =
                (data['ingredients'] as List<dynamic>?)
                        ?.map((ing) => Ingredient(
                            name: ing['name'], quantity: ing['quantity']))
                        .toList() ??
                    [];

            final List<String> steps = (data['steps'] as List<dynamic>?)
                    ?.map((step) => step.toString())
                    .toList() ??
                [];

            String statusHalal = data['halal_status'] ?? 'Halal';

            for (var ingredient in ingredients) {
              final lowerIngredient = ingredient.name.toLowerCase();
                if (lowerIngredient.contains('pork') ||
                  lowerIngredient.contains('babi') ||
                  lowerIngredient.contains('wine') ||
                  lowerIngredient.contains('alcohol') ||
                  lowerIngredient.contains('bacon') ||
                  lowerIngredient.contains('ham')) {
                if (statusHalal.toLowerCase() != 'resep makanan hewan') {
                  statusHalal = "Non Halal (Bahan Terdeteksi)";
                  break;
                }
              }
            }

            aiFavorites.add(Recipe(
              id: 0,
              title: data['title'] ?? 'Resep AI Tanpa Judul',
              description: '',
              duration: data['duration'] ?? '',
              servings: data['servings'] ?? '',
              imageUrl: data['image_url'] ?? '',
              mainIngredients: [],
              allIngredients: ingredients,
              steps: steps,
              isFavorite: true,
              isAiGenerated: true,
              score: 0,
              halalStatus: statusHalal,
            ));
          } catch (e) {
            debugPrint("Gagal konversi resep AI favorit: $e");
          }
        }
      }

      final allFavorites = [...aiFavorites, ...normalFavorites];
      await favBox.clear();
      Map<String, Recipe> favMap = { for (var r in allFavorites) r.title : r };
      await favBox.putAll(favMap);
      debugPrint("--- Sukses fetch & simpan favorit ke cache ---");
      
      return allFavorites;

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Gagal muat data baru. Nampilin data terakhir... (${e.toString()})'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
      return favBox.values.toList();
    }
  }

  Future<void> _refreshFavorites() async {
    if (context.read<ConnectivityProvider>().isOffline) {
      final lang = Provider.of<LanguageProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.getText('fav_offline_refresh'))),
      );
      return;
    }
    setState(() {
      _allFavoriteRecipesFuture = _loadAllFavoriteRecipes();
    });
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : Colors.black87,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = context.watch<ConnectivityProvider>().isOffline;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFFAFAFA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : const Color(0xFFFFF8F0),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE74C3C), Color(0xFFC0392B)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              'Resep Favorit',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [const Color(0xFF1A1A2E), const Color(0xFF121212)]
                : [const Color(0xFFFFF8F0), const Color(0xFFFAFAFA)],
          ),
        ),
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: FutureBuilder<List<Recipe>>(
                future: _allFavoriteRecipesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.orange));
                  }

                  if (snapshot.hasData) {
                    final allFavoriteRecipes = snapshot.data!;

                    if (allFavoriteRecipes.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.9, end: 1.0),
                              duration: const Duration(milliseconds: 800),
                              curve: Curves.elasticOut,
                              builder: (context, value, child) {
                                return Transform.scale(scale: value, child: child);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isDarkMode
                                        ? [const Color(0xFF2A2520).withOpacity(0.5), const Color(0xFF1E1A18).withOpacity(0.3)]
                                        : [Colors.red.shade50, Colors.red.shade100.withOpacity(0.5)],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.favorite_border_rounded, size: 60, color: Colors.red),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Belum ada resep favorit',
                              style: TextStyle(
                                fontSize: 18, 
                                color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40.0),
                              child: Text(
                                'Resep AI & resep biasa yang kamu suka akan muncul di sini ❤️',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final aiRecipes =
                        allFavoriteRecipes.where((r) => r.isAiGenerated).toList();
                    final normalRecipes = allFavoriteRecipes
                        .where((r) => !r.isAiGenerated)
                        .toList();

                    return RefreshIndicator(
                      onRefresh: isOffline ? () async {} : _refreshFavorites,
                      color: Colors.orange,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (aiRecipes.isNotEmpty) ...[
                              _buildSectionHeader('Resep Buatan AI', Icons.auto_awesome_rounded, Colors.orange, isDarkMode),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                itemCount: aiRecipes.length,
                                itemBuilder: (context, index) {
                                  final recipe = aiRecipes[index];
                                  return GestureDetector(
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              RecipeDetailScreen(recipe: recipe),
                                        ),
                                      );
                                      if (!isOffline) {
                                        _refreshFavorites();
                                      }
                                    },
                                    child: RecipeCard(recipe: recipe),
                                  );
                                },
                              ),
                            ],
                            if (normalRecipes.isNotEmpty) ...[
                              _buildSectionHeader('Resep dari Database', Icons.restaurant_menu_rounded, Colors.blue, isDarkMode),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                itemCount: normalRecipes.length,
                                itemBuilder: (context, index) {
                                  final recipe = normalRecipes[index];
                                  return GestureDetector(
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              RecipeDetailScreen(recipe: recipe),
                                        ),
                                      );
                                      if (!isOffline) {
                                        _refreshFavorites();
                                      }
                                    },
                                    child: RecipeCard(recipe: recipe),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }

                  return const Center(
                      child: Text('Terjadi kesalahan tidak terduga.'));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
