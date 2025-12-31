import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'ingredient_model.dart';

part 'recipe_model.g.dart';

@HiveType(typeId: 5)
class Recipe {
  @HiveField(0)
  int id;
  @HiveField(1)
  final String title;
  @HiveField(2)
  final String description;
  @HiveField(3)
  final String duration;
  @HiveField(4)
  final String servings;
  @HiveField(5)
  String imageUrl;
  @HiveField(6)
  final List<String> mainIngredients;
  @HiveField(7)
  final List<Ingredient> allIngredients;
  @HiveField(8)
  final List<String> steps;
  @HiveField(9)
  double score;
  @HiveField(10)
  bool isFavorite;
  @HiveField(11)
  final bool isAiGenerated;
  @HiveField(12)
  final String halalStatus;
  
  // --- UPDATE BARU: FIELD NUTRISI ---
  @HiveField(13)
  final Map<String, String> nutrition; 

  Recipe({
    required this.id,
    required this.title,
    required this.description,
    required this.duration,
    required this.servings,
    required this.imageUrl,
    required this.mainIngredients,
    required this.allIngredients,
    required this.steps,
    this.score = 0.0,
    this.isFavorite = false,
    this.isAiGenerated = false,
    this.halalStatus = "Halal",
    this.nutrition = const {}, // Default kosong biar gak error data lama
  });

  factory Recipe.fromJson(Map<String, dynamic> json,
      {bool isGeneratedByAi = false}) {
    List<Ingredient> ingredientsList = [];
    List<String> mainIngredientsList = [];
    List<String> stepsList = [];

    String statusHalal = "Halal";

    // --- HELPER: PAWANG DATA ---
    List<String> parseStringList(dynamic data) {
      if (data is List) {
        return data.map((e) => e.toString()).toList();
      } else if (data is String) {
        return [data];
      } else if (data is Map) {
        return data.values.map((e) => e.toString()).toList();
      }
      return [];
    }
    
    // Helper safe nutrition parsing
    Map<String, String> parseNutrition(dynamic value) {
      if (value is Map) {
        return {
          'calories': value['calories']?.toString() ?? '-',
          'protein': value['protein']?.toString() ?? '-',
          'carbs': value['carbs']?.toString() ?? '-',
          'fat': value['fat']?.toString() ?? '-',
        };
      }
      return {}; // Kosongin aja kalau gak ada datanya
    }
    // --------------------------------------------

    if (isGeneratedByAi) {
      statusHalal = json['halal_status']?.toString() ?? 'Halal';

      // 1. Handle all_ingredients
      var rawIngredients = json['all_ingredients'];
      if (rawIngredients is List) {
        ingredientsList = rawIngredients.map((i) {
            if (i is Map<String, dynamic>) {
              return Ingredient.fromJson(i);
            } else {
              return Ingredient(name: i.toString(), quantity: '');
            }
          }).toList();
      } else if (rawIngredients is Map) {
        if (rawIngredients.containsKey('name')) {
          ingredientsList = [Ingredient.fromJson(Map<String, dynamic>.from(rawIngredients))];
        } else {
          for (var val in rawIngredients.values) {
             if (val is Map<String, dynamic>) {
               ingredientsList.add(Ingredient.fromJson(val));
             }
          }
        }
      }

      // 2. Handle main_ingredients
      mainIngredientsList = parseStringList(json['main_ingredients']);

      // 3. Handle steps
      stepsList = parseStringList(json['steps']);

    } else {
      // LOGIKA DATABASE (SUPABASE)
      if (json['main_ingredients'] is List) {
        mainIngredientsList = List<String>.from(json['main_ingredients']);
      }

      if (json['steps'] is List) {
        stepsList = List<String>.from(json['steps']);
      }

      try {
        if (json['ingredients'] is String) {
           List<dynamic> ingredientStrings = jsonDecode(json['ingredients']);
           if (ingredientStrings.isNotEmpty) {
             ingredientsList = ingredientStrings
                 .map((name) => Ingredient(name: name.toString(), quantity: ''))
                 .toList();
           }
        } else if (json['ingredients'] is List) {
           ingredientsList = (json['ingredients'] as List).map((x) {
              if (x is Map) return Ingredient.fromJson(Map<String, dynamic>.from(x));
              return Ingredient(name: x.toString(), quantity: '');
           }).toList();
        }
      } catch (e) {
        // ignore error
      }

      if (ingredientsList.isEmpty && mainIngredientsList.isNotEmpty) {
        ingredientsList = mainIngredientsList
            .map((name) => Ingredient(name: name, quantity: ''))
            .toList();
      }

      // Logic Auto-Detect Halal
      for (var ingredient in mainIngredientsList) {
        final lowerIngredient = ingredient.toLowerCase();
        if (lowerIngredient.contains('pork') ||
            lowerIngredient.contains('babi') ||
            lowerIngredient.contains('wine') ||
            lowerIngredient.contains('alcohol') ||
            lowerIngredient.contains('bacon') ||
            lowerIngredient.contains('ham')) {
          statusHalal = "Non Halal (Bahan Terdeteksi)";
          break;
        }
      }
    }

    return Recipe(
      id: isGeneratedByAi ? 0 : (json['id'] as num? ?? 0).toInt(),
      title: json['title']?.toString() ?? 'Tanpa Judul',
      description: json['description']?.toString() ?? '',
      duration: json['duration']?.toString() ?? '',
      servings: json['servings']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      allIngredients: ingredientsList,
      mainIngredients: mainIngredientsList,
      steps: stepsList,
      isAiGenerated: isGeneratedByAi,
      halalStatus: statusHalal,
      score: (json['score'] as num? ?? 0.0).toDouble(),
      isFavorite: json['isFavorite'] ?? false,
      nutrition: parseNutrition(json['nutrition']), // Load Nutrisi
    );
  }

  Map<String, dynamic> toJson() {
    final List<String> ingredientNames =
        allIngredients.map((ing) => ing.name).toList();
    final String ingredientsJsonString = jsonEncode(ingredientNames);

    return {
      'title': title,
      'description': description,
      'duration': duration,
      'servings': servings,
      'image_url': imageUrl,
      'ingredients': ingredientsJsonString,
      'main_ingredients': mainIngredients,
      'steps': steps,
      'halal_status': halalStatus,
      'nutrition': nutrition, // Simpan Nutrisi
    };
  }
}