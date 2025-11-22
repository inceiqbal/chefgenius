import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/recipe_model.dart';

class GeneratedRecipeProvider extends ChangeNotifier {
  static const _boxName = 'ai_recipes_box'; 
  
  List<Recipe> _generatedRecipes = [];
  bool _isGenerating = false;
  String? _error;
  bool _isInitialized = false; 

  // FIX 1: Ganti tipe Box jadi 'Box' biasa (dynamic) biar gak crash pas baca List
  // Jangan pake Box<List<Recipe>> karena Hive suka balikin List<dynamic>
  Box? _recipeBox;

  List<Recipe> get generatedRecipes => _generatedRecipes;
  bool get isGenerating => _isGenerating;
  String? get error => _error;
  bool get isInitialized => _isInitialized;

  // Fungsi bantu: buka box hanya kalau belum terbuka
  Future<void> _openBoxIfNeeded() async {
    if (_recipeBox == null || !_recipeBox!.isOpen) {
      // FIX 2: Buka sebagai box general
      _recipeBox = await Hive.openBox(_boxName);
    }
  }

  Future<void> loadRecipes() async {
    try {
      await _openBoxIfNeeded();

      // FIX 3: Ambil data sebagai dynamic dulu
      final dynamic storedList = _recipeBox!.get('list');
      
      // FIX 4: Cek dan Cast manual (The Magic Trick 🎩✨)
      if (storedList != null && storedList is List) {
        // Kita paksa ubah item di dalemnya jadi Recipe satu-satu
        // .cast<Recipe>() ini penyelamatnya!
        _generatedRecipes = storedList.cast<Recipe>().toList();
      }
    } catch (e) {
      debugPrint("Gagal load resep dari Hive: $e");
      // Kalau gagal load (misal format lama beda), kita reset aja biar aman
      _generatedRecipes = [];
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _saveRecipes() async {
    try {
      await _openBoxIfNeeded(); 
      await _recipeBox!.put('list', _generatedRecipes);
    } catch (e) {
      debugPrint("Gagal save resep ke Hive: $e");
    }
  }

  void setRecipes(List<Recipe> recipes) {
    _generatedRecipes = recipes;
    _isGenerating = false;
    _error = null;

    _saveRecipes(); // aman dipanggil kapan pun
    notifyListeners();
  }

  void startLoading() {
    _isGenerating = true;
    _error = null;
    notifyListeners();
  }

  void setError(String error) {
    _isGenerating = false;
    _error = error;
    notifyListeners();
  }
}