import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../../app/data/models/recipe_model.dart';
import '../widgets/recipe_card.dart';
import '../../../app/widgets/custom_app_bar.dart'; 

class RecipeListScreen extends StatelessWidget {
  final List<Recipe> recipes;

  const RecipeListScreen({super.key, required this.recipes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- 2. GUNAKAN CUSTOM APP BAR ---
      appBar: const CustomAppBar(title: 'Hasil Rekomendasi'),
      // -------------------------------
      body: recipes.isEmpty
          ? const Center(
              child: Text(
                'Tidak ada resep yang cocok ditemukan.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          // --- PEMBUNGKUS ANIMASI UTAMA ---
          : AnimationLimiter(
              child: ListView.builder(
                padding: const EdgeInsets.all(12.0),
                itemCount: recipes.length,
                itemBuilder: (context, index) {
                  // --- KONFIGURASI ANIMASI PER ITEM ---
                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 375),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: RecipeCard(recipe: recipes[index]),
                      ),
                    ),
                  );
                  // -------------------------------------
                },
              ),
            ),
    );
  }
}