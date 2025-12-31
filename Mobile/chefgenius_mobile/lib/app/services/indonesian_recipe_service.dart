import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../data/models/recipe_model.dart';
import '../data/models/ingredient_model.dart';

class IndonesianRecipeService {
  // Base URL yang baru (Vercel)
  static const String _baseUrl = 'https://masak-apa.tomorisakura.vercel.app';

  // Gambar cadangan kalau resep asli gak punya foto (Biar gak broken icon)
  static const String _placeholderImage = 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?q=80&w=1000&auto=format&fit=crop';

  // 1. Cari Resep (Search)
  Future<List<Recipe>> searchRecipes(String query) async {
    try {
      final url = Uri.parse('$_baseUrl/api/search/?q=$query');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final results = json['results'] as List;

        return results.map((data) {
          // Logika Gambar Anti-Null
          String imgUrl = data['thumb'] ?? '';
          if (imgUrl.isEmpty) {
            imgUrl = _placeholderImage;
          }

          return Recipe(
            id: (data['key'] as String).hashCode, 
            title: data['title'] ?? 'Tanpa Judul',
            description: 'Resep Masakan Indonesia. Klik untuk melihat detail lengkap.', 
            duration: data['times'] ?? '', 
            servings: data['serving'] ?? '',
            imageUrl: imgUrl, // <-- Pake URL yang udah diamankan
            mainIngredients: [], 
            allIngredients: [],
            steps: [],
            isAiGenerated: false, 
            halalStatus: "Menu Indonesia (Cek Detail)",
          );
        }).toList();
      }
    } catch (e) {
      debugPrint("Gagal cari resep Indo: $e");
    }
    return [];
  }

  // 2. Ambil Detail Lengkap
  Future<Recipe?> getRecipeDetail(String recipeKey) async {
    try {
      final url = Uri.parse('$_baseUrl/api/recipe/$recipeKey');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json['results'];

        List<Ingredient> ingredients = [];
        if (data['ingredient'] != null) {
          ingredients = (data['ingredient'] as List).map((item) {
            return Ingredient(name: item.toString(), quantity: ''); 
          }).toList();
        }

        List<String> steps = [];
        if (data['step'] != null) {
           steps = (data['step'] as List).map((item) => item.toString()).toList();
        }

        // Logika Gambar Anti-Null untuk Detail
        String imgUrl = data['thumb'] ?? '';
        if (imgUrl.isEmpty) {
           imgUrl = _placeholderImage;
        }

        return Recipe(
          id: recipeKey.hashCode, 
          title: data['title'] ?? '',
          description: data['desc'] ?? 'Deskripsi tidak tersedia.',
          duration: data['times'] ?? '',
          servings: data['servings'] ?? '',
          imageUrl: imgUrl, // <-- Pake URL yang udah diamankan
          mainIngredients: ingredients.map((e) => e.name).toList(),
          allIngredients: ingredients,
          steps: steps,
          isAiGenerated: false,
          halalStatus: "Menu Indonesia",
        );
      }
    } catch (e) {
      debugPrint("Gagal fetch detail resep Indo: $e");
    }
    return null;
  }
}