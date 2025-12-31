import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/recipe_model.dart';
import 'package:chefgenius/app/data/utils/ingredient_matcher.dart';

class RecommendationService {
  static final RecommendationService _instance = RecommendationService._internal();
  factory RecommendationService() {
    return _instance;
  }
  RecommendationService._internal();

  final supabase = Supabase.instance.client;
  
  // Placeholder Image (Ban Serep)
  static const String _placeholderImage = 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?q=80&w=1000&auto=format&fit=crop';

  // --- FUNGSI PENERJEMAH (TRANSLATOR) ---
  // Ini sekarang pake IngredientMatcher biar sinkron sama kamus pusat
  List<String> _translateToEnglish(List<String> inputItems) {
    // Map setiap item pake fungsi normalize dari Matcher
    return inputItems.map((item) => IngredientMatcher.normalize(item)).toList();
  }
  // ---------------------------------------

  /// Gets recommendations based on pantry items by calling Supabase RPC.
  Future<List<Recipe>> getRecommendations(List<String> pantryItems) async {
    if (pantryItems.isEmpty) return [];

    try {
      // 1. TERJEMAHKAN DULU SEBELUM KIRIM KE SERVER (Biar Telur -> egg)
      final List<String> englishPantryItems = _translateToEnglish(pantryItems);

      // 2. Panggil "Otak" kita di Supabase (RPC)
      final List<dynamic> data = await supabase.rpc(
        'get_recommendations', 
        params: {
          'p_pantry_items': englishPantryItems
        },
      );

      // 3. Ambil ID favorit user buat nandain love
      final userId = supabase.auth.currentUser?.id;
      List<int> favoriteIds = [];
      if (userId != null) {
        final List<dynamic> favorites = await supabase
            .from('favorite_recipes')
            .select('recipe_id')
            .eq('user_id', userId);
        favoriteIds = favorites.map((f) => f['recipe_id'] as int).toList();
      }

      // 4. Ubah data JSON yg balik dari server jadi List<Recipe>
      List<Recipe> recommendations = data.map((json) {
        final recipe = Recipe.fromJson(json, isGeneratedByAi: false);
        
        // --- FIX LOGIC GAMBAR (SAMA KAYAK SEARCH SCREEN) ---
        final String dbImageUrl = json['image_url'] ?? '';
        
        if (dbImageUrl.isNotEmpty) {
          // 1. Kalau linknya dari Supabase project kita (Data Lama yg Path-nya salah)
          if (dbImageUrl.contains('supabase.co')) {
             // Ambil nama filenya aja (buang path salahnya)
             final String filename = dbImageUrl.split('/').last;
             // Kita paksa arahin ke folder 'Food Images' yang bener
             recipe.imageUrl = supabase.storage
                .from('recipe-images')
                .getPublicUrl('Food Images/$filename');
          }
          // 2. Kalau link dari website luar (API Indo/Hosting lain)
          else if (dbImageUrl.startsWith('http')) {
             recipe.imageUrl = dbImageUrl; // Pake langsung
          }
          // 3. Kalau cuma nama file doang (Data Baru)
          else {
             final String filename = dbImageUrl.split('/').last; 
             recipe.imageUrl = supabase.storage
                .from('recipe-images')
                .getPublicUrl('Food Images/$filename');
          }
        } else {
          // 4. Kalau kosong, pake Placeholder
          recipe.imageUrl = _placeholderImage;
        }
        // ---------------------------------------------------

        // Set status favorit
        recipe.isFavorite = favoriteIds.contains(recipe.id);
        
        // Ambil skornya
        recipe.score = (json['score'] as num? ?? 0.0).toDouble();

        return recipe;
      }).toList();

      return recommendations;

    } catch (e) {
      debugPrint('Error manggil RPC get_recommendations: $e');
      return [];
    }
  }

  void clearCache() {
    debugPrint("--- clearCache() dipanggil, tapi udah gak ada cache resep ---");
  }
}