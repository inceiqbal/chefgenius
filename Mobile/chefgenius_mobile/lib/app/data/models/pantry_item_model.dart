import 'package:hive_flutter/hive_flutter.dart';

part 'pantry_item_model.g.dart';

@HiveType(typeId: 6) // typeId 6 karena 0-5 sudah dipakai
class PantryItem {
  @HiveField(0)
  final int id; // Supabase ID untuk sync

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String quantity; // "100 gram", "2 butir", "1/2 sdm", atau ""

  PantryItem({
    required this.id,
    required this.name,
    required this.quantity,
  });

  // Convert to Map for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ingredient_name': name,
      'quantity': quantity,
    };
  }

  // Create from Supabase response
  factory PantryItem.fromJson(Map<String, dynamic> json) {
    return PantryItem(
      id: json['id'] as int,
      name: json['ingredient_name'] as String,
      quantity: json['quantity'] as String? ?? '',
    );
  }

  // Display format: "Telur 2 butir" atau "Garam" (jika quantity kosong)
  String get displayName {
    if (quantity.isEmpty) {
      return name;
    }
    return '$name $quantity';
  }

  @override
  String toString() => displayName;
}
