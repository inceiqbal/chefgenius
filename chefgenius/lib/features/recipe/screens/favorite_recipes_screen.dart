import 'package:chefgenius/app/data/models/ingredient_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../app/data/models/recipe_model.dart';
// RecommendationService udah gak kita pake di file ini
import '../../../app/widgets/custom_app_bar.dart';
import '../widgets/recipe_card.dart';
import '../screens/recipe_detail_screen.dart';
import '../../../app/data/providers/connectivity_provider.dart';
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

      // --- BAGIAN RESEP NORMAL (CARA BARU YANG NGEBUT) ---

      // 1. Ambil list ID favorit kita
      final List<dynamic> idData = await supabase
          .from('favorite_recipes')
          .select('recipe_id')
          .eq('user_id', userId);

      if (idData.isNotEmpty) {
        final List<int> favoriteRecipeIds =
            idData.map((fav) => fav['recipe_id'] as int).toList();

        // 2. Ambil detail resep HANYA untuk ID yang kita punya
        // --- INI DIA FIX-NYA (Pake .filter() versi lama yg pasti aman) ---
        final List<dynamic> recipeData = await supabase
            .from('recipes')
            .select('*') // <-- SELECT DULU
            .filter('id', 'in', favoriteRecipeIds); // <-- BARU FILTER PAKE CARA INI
        // ----------------------------------------------------------------

        // 3. Ubah JSON jadi List<Recipe>
        final List<Recipe> foundNormalFavorites = recipeData.map((json) {
          final recipe = Recipe.fromJson(json, isGeneratedByAi: false);

          final String dbImageUrl = json['image_url'] ?? '';
          if (dbImageUrl.isNotEmpty) {
            final String filename = dbImageUrl.split('/').last;
            recipe.imageUrl = supabase.storage
                .from('recipe-images')
                .getPublicUrl('Food Images/$filename');
          }

          recipe.isFavorite = true; // Pasti favorit
          return recipe;
        }).toList();

        normalFavorites.addAll(foundNormalFavorites);
      }

      // --- BAGIAN RESEP AI (TETAP SAMA, UDAH BENER) ---
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

            // Cek ulang statusnya
            for (var ingredient in ingredients) {
              final lowerIngredient = ingredient.name.toLowerCase();
              if (lowerIngredient.contains('pork') ||
                  lowerIngredient.contains('babi') ||
                  lowerIngredient.contains('wine') ||
                  lowerIngredient.contains('alcohol') ||
                  lowerIngredient.contains('bacon') ||
                  lowerIngredient.contains('ham')) {
                if (statusHalal.toLowerCase() != 'resep makanan hewan') {
                  statusHalal = "Haram (Bahan Terdeteksi)";
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

      // 4. KALO BERHASIL: Gabungin & Simpen ke Cache Hive
      final allFavorites = [...aiFavorites, ...normalFavorites];
      await favBox.clear();
      Map<String, Recipe> favMap = { for (var r in allFavorites) r.title : r };
      await favBox.putAll(favMap);
      debugPrint("--- Sukses fetch & simpan favorit ke cache ---");
      
      return allFavorites;

    } catch (e) {
      // 5. KALO GAGAL (meskipun online, misal Supabase error):
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Gagal muat data baru. Nampilin data terakhir... (${e.toString()})'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
      // Pake cache sebagai fallback
      return favBox.values.toList();
    }
  }

  Future<void> _refreshFavorites() async {
    if (context.read<ConnectivityProvider>().isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kamu lagi offline, gak bisa refresh.')),
      );
      return;
    }
    setState(() {
      _allFavoriteRecipesFuture = _loadAllFavoriteRecipes();
    });
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = context.watch<ConnectivityProvider>().isOffline;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Resep Favorit'),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: FutureBuilder<List<Recipe>>(
              future: _allFavoriteRecipesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasData) {
                  final allFavoriteRecipes = snapshot.data!;

                  if (allFavoriteRecipes.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.favorite_border,
                              size: 80, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Anda belum punya resep favorit.',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 40.0, vertical: 8.0),
                            child: Text(
                              'Resep AI & resep biasa yang Anda suka akan muncul di sini.',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                  height: 1.4),
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
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (aiRecipes.isNotEmpty) ...[
                            _buildSectionHeader('Resep Buatan AI'),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
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
                            _buildSectionHeader('Resep Favorit Biasa'),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
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
    );
  }
}