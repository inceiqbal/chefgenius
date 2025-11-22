import 'package:hive_flutter/hive_flutter.dart';

part 'ingredient_model.g.dart';

@HiveType(typeId: 4) // Harus unik
class Ingredient {
  @HiveField(0)
  final String name;
  @HiveField(1)
  final String quantity;

  Ingredient({
    required this.name,
    required this.quantity,
  });

  // Fungsi dari JSON (untuk resep AI)
  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      name: json['name'],
      quantity: json['quantity'],
    );
  }
}