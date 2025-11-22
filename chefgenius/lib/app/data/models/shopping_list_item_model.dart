import 'package:hive/hive.dart';

// JANGAN LUPA JALANIN: flutter pub run build_runner build
// Kalau error conflict, pake: flutter pub run build_runner build --delete-conflicting-outputs
part 'shopping_list_item_model.g.dart';

@HiveType(typeId: 6) // ID 6 Sesuai punya lo
class ShoppingListItem extends HiveObject {
  @HiveField(0)
  String itemName;

  @HiveField(1)
  bool isChecked;

  @HiveField(2)
  String recipeTitle;

  // PERBAIKAN 1: INI WAJIB JADI HIVEFIELD!
  // Biar pas aplikasi ditutup & dibuka lagi (offline), kita tetep inget ID server-nya.
  @HiveField(3)
  int? supabaseId; 

  ShoppingListItem({
    required this.itemName,
    this.isChecked = false,
    this.recipeTitle = '', // Default mending kosong, biar Provider yang nentuin logic-nya
    this.supabaseId,
  });

  // Helper buat convert dari JSON (Supabase) ke Object
  factory ShoppingListItem.fromJson(Map<String, dynamic> json) {
    return ShoppingListItem(
      itemName: json['item_name'] ?? 'Tanpa Nama',
      isChecked: json['is_checked'] ?? false,
      
      // PERBAIKAN 2: Handle NULL dari Supabase
      // Kalau null, ubah jadi string kosong ''. 
      // Provider nanti bakal baca '' ini dan otomatis masukin ke grup "Tambahan Lain".
      recipeTitle: json['recipe_title'] ?? '', 
      
      supabaseId: json['id'], // Ini ambil ID integer dari Supabase
    );
  }

  // Helper buat convert dari Object ke JSON (Supabase)
  Map<String, dynamic> toJson(String userId) {
    return {
      'user_id': userId,
      'item_name': itemName,
      'is_checked': isChecked,
      
      // Kalau kosong, kirim null atau string kosong (tergantung schema DB). 
      // Karena di DB lo boleh null, kita kirim null kalau kosong biar rapi.
      'recipe_title': recipeTitle.isEmpty ? null : recipeTitle,
    };
  }
}