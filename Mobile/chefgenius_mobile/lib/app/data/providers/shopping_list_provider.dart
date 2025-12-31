import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shopping_list_item_model.dart';

class ShoppingListProvider extends ChangeNotifier {
  final supabase = Supabase.instance.client;
  late Box<ShoppingListItem> _box;
  
  List<ShoppingListItem> _items = [];
  bool _isLoading = true;

  List<ShoppingListItem> get items => _items;
  bool get isLoading => _isLoading;

  // Grouping Data
  Map<String, List<ShoppingListItem>> get groupedItems {
    Map<String, List<ShoppingListItem>> groups = {};
    for (var item in _items) {
      // Pastikan resep yang sama masuk grup yang sama
      // Kalau kosong, masuk ke 'Tambahan Lain'
      String key = item.recipeTitle.isEmpty ? 'Tambahan Lain' : item.recipeTitle;
      if (!groups.containsKey(key)) {
        groups[key] = [];
      }
      groups[key]!.add(item);
    }
    return groups;
  }

  // --- HELPER: Pastikan Box Terbuka ---
  Future<void> _ensureBoxOpen() async {
    if (!Hive.isBoxOpen('shopping_list_box')) {
      _box = await Hive.openBox<ShoppingListItem>('shopping_list_box');
    } else {
      _box = Hive.box<ShoppingListItem>('shopping_list_box');
    }
  }

  // Load Data
  Future<void> loadItems(bool isOffline) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _ensureBoxOpen(); // Ganti logika manual dengan helper

      if (isOffline) {
        _loadFromHive();
      } else {
        await _loadFromSupabase();
      }
    } catch (e) {
      debugPrint("Error loading shopping list: $e");
      // Fallback ke Hive kalau Supabase error
      if (Hive.isBoxOpen('shopping_list_box')) {
         _loadFromHive();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _loadFromHive() {
    if (_box.isOpen) {
      _items = _box.values.toList();
      // Sort biar yang baru di atas
      _items.sort((a, b) => b.key.toString().compareTo(a.key.toString()));
      notifyListeners();
    }
  }

  Future<void> _loadFromSupabase() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      _loadFromHive();
      return;
    }

    final response = await supabase
        .from('shopping_list_items')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    List<ShoppingListItem> onlineItems = [];
    for (var data in response) {
      onlineItems.add(ShoppingListItem.fromJson(data));
    }

    await _box.clear();
    await _box.addAll(onlineItems);

    _items = onlineItems;
    notifyListeners();
  }

  // Tambah Item Manual
  Future<void> addItem(String name, bool isOffline) async {
    await addIngredientsFromRecipe([name], 'Tambahan Lain', isOffline);
  }

  // Tambah Banyak dari Resep
  Future<void> addIngredientsFromRecipe(List<String> ingredients, String recipeTitle, bool isOffline) async {
    if (ingredients.isEmpty) return;

    // --- PERBAIKAN UTAMA: Pastikan box terbuka sebelum akses ---
    await _ensureBoxOpen();
    // ---------------------------------------------------------

    // 1. Bikin List Object
    List<ShoppingListItem> newItems = ingredients.map((name) => ShoppingListItem(
      itemName: name,
      isChecked: false,
      recipeTitle: recipeTitle,
    )).toList();

    // 2. Simpan ke Hive (Lokal)
    // Load current items from box first to ensure _items matches box content if it was just opened
    if (_items.isEmpty && _box.isNotEmpty) {
       _items = _box.values.toList();
    }

    bool hasChanges = false;
    for (var item in newItems) {
      // Cek duplikasi
      bool exists = _items.any((existing) => 
          existing.itemName.toLowerCase() == item.itemName.toLowerCase() && 
          existing.recipeTitle == item.recipeTitle);
      
      if (!exists) {
        await _box.add(item);
        _items.insert(0, item);
        hasChanges = true;
      }
    }
    
    if (hasChanges) {
      notifyListeners();
    }

    // 3. Simpan ke Supabase (Cloud)
    if (!isOffline) {
      try {
        final userId = supabase.auth.currentUser?.id;
        if (userId != null) {
          // Filter item yang duplikat (sudah ada di local/server) logic sederhana
          final dataToInsert = newItems.map((item) => item.toJson(userId)).toList();
          await supabase.from('shopping_list_items').insert(dataToInsert);
          
          // Reload biar dapet ID dari server
          _loadFromSupabase();
        }
      } catch (e) {
        debugPrint("Gagal sync batch ke Supabase: $e");
      }
    }
  }

  Future<void> toggleCheck(ShoppingListItem item, bool val, bool isOffline) async {
    await _ensureBoxOpen(); // Safety check

    item.isChecked = val;
    item.save(); 
    notifyListeners();

    if (!isOffline && item.supabaseId != null) {
      try {
        await supabase.from('shopping_list_items').update({'is_checked': val}).eq('id', item.supabaseId!);
      } catch (e) {
        debugPrint("Gagal sync checklist: $e");
      }
    }
  }

  // --- FITUR BARU: Toggle Select All ---
  Future<void> toggleAll(bool targetStatus, bool isOffline) async {
    await _ensureBoxOpen(); // Safety check

    // Update state lokal dulu biar UI responsif
    for (var item in _items) {
      if (item.isChecked != targetStatus) {
        item.isChecked = targetStatus;
        item.save(); // Save Hive
      }
    }
    notifyListeners();

    // Sync ke server
    if (!isOffline) {
       final userId = supabase.auth.currentUser?.id;
       if (userId != null) {
         try {
           await supabase.from('shopping_list_items')
             .update({'is_checked': targetStatus})
             .eq('user_id', userId);
         } catch (e) {
            debugPrint("Gagal sync toggle all: $e");
         }
       }
    }
  }

  // Hapus Satu Item
  Future<void> deleteItem(ShoppingListItem item, bool isOffline) async {
    await _ensureBoxOpen(); // Safety check

    _items.remove(item);
    await item.delete(); 
    notifyListeners();

    if (!isOffline && item.supabaseId != null) {
      try {
        await supabase.from('shopping_list_items').delete().eq('id', item.supabaseId!);
      } catch (e) {
        debugPrint("Gagal hapus di server: $e");
      }
    }
  }

  Future<void> deleteGroup(String recipeTitle, bool isOffline) async {
    await _ensureBoxOpen(); // Safety check

    final isManualGroup = recipeTitle == 'Tambahan Lain';

    // 1. Filter yang BENAR
    final itemsToDelete = _items.where((i) {
      if (isManualGroup) {
        return i.recipeTitle == recipeTitle || i.recipeTitle.isEmpty;
      }
      return i.recipeTitle == recipeTitle;
    }).toList();

    // 2. Hapus dari Memory & Hive
    for (var item in itemsToDelete) {
      _items.remove(item);
      await item.delete();
    }
    notifyListeners();

    // 3. Hapus dari Supabase
    if (!isOffline) {
      try {
        final userId = supabase.auth.currentUser?.id;
        if (userId != null) {
            if (isManualGroup) {
               // Hapus yang eksplisit 'Tambahan Lain'
               await supabase.from('shopping_list_items')
                 .delete()
                 .eq('user_id', userId)
                 .eq('recipe_title', 'Tambahan Lain');
               
               // Hapus juga yang string kosong (hantu-hantunya)
               await supabase.from('shopping_list_items')
                 .delete()
                 .eq('user_id', userId)
                 .eq('recipe_title', '');
            } else {
               // Hapus grup resep biasa
               await supabase.from('shopping_list_items')
                 .delete()
                 .eq('user_id', userId)
                 .eq('recipe_title', recipeTitle);
            }
        }
      } catch (e) {
        debugPrint("Gagal hapus grup di server: $e");
      }
    }
  }
}