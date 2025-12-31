import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // WAJIB IMPORT INI
import '../models/recipe_model.dart';

class GeneratedRecipeProvider extends ChangeNotifier {
  // Kita HAPUS static _boxName biar gak dipake rame-rame
  
  List<Recipe> _generatedRecipes = [];
  bool _isGenerating = false;
  String? _error;
  
  // Supabase Client buat ambil User ID
  final supabase = Supabase.instance.client;

  List<Recipe> get generatedRecipes => _generatedRecipes;
  bool get isGenerating => _isGenerating;
  String? get error => _error;

  // --- FUNGSI UTAMA: LOAD RESEP PER USER ---
  Future<void> loadRecipes() async {
    try {
      // 1. Ambil ID User yang lagi login
      final userId = supabase.auth.currentUser?.id;
      
      // Kalau belum login, jangan load apa-apa (kosongin list)
      if (userId == null) {
         _generatedRecipes = [];
         notifyListeners();
         return;
      }

      // 2. Bikin Nama Kotak UNIK per User
      final boxName = 'ai_recipes_$userId'; 

      // 3. Buka Box
      Box box;
      if (!Hive.isBoxOpen(boxName)) {
        box = await Hive.openBox(boxName);
      } else {
        box = Hive.box(boxName);
      }

      // 4. Ambil data 'list' (Logic kamu yang udah bener buat handle tipe data)
      final dynamic storedList = box.get('list');
      
      if (storedList != null && storedList is List) {
        // Magic Trick: Cast manual biar gak error type 'List<dynamic>' is not subtype of 'List<Recipe>'
        _generatedRecipes = storedList.cast<Recipe>().toList();
      } else {
        _generatedRecipes = [];
      }

    } catch (e) {
      debugPrint("Gagal load resep dari Hive: $e");
      _generatedRecipes = [];
    } finally {
      notifyListeners();
    }
  }

  // --- FUNGSI SAVE KE KOTAK USER ---
  Future<void> _saveToLocal() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return; // Gak simpen kalo gak ada user

      // Pake nama kotak yang SAMA persis kayak pas load
      final boxName = 'ai_recipes_$userId';
      
      Box box;
      if (!Hive.isBoxOpen(boxName)) {
        box = await Hive.openBox(boxName);
      } else {
        box = Hive.box(boxName);
      }

      // Simpan list resep ke key 'list'
      await box.put('list', _generatedRecipes);
      
    } catch (e) {
      debugPrint("Gagal save resep ke Hive: $e");
    }
  }

  // Dipanggil dari UI pas sukses generate
  void setRecipes(List<Recipe> recipes) {
    _generatedRecipes = recipes;
    _isGenerating = false;
    _error = null;

    _saveToLocal(); // Otomatis simpen ke kotak user yang aktif
    notifyListeners();
  }

  void startLoading() {
    _isGenerating = true;
    _error = null;
    notifyListeners();
  }

  void setError(String message) {
    _isGenerating = false;
    _error = message;
    notifyListeners();
  }
  
  // Bersihin data di memori pas Logout (Optional tapi bagus)
  void clearData() {
    _generatedRecipes = [];
    notifyListeners();
  }
}