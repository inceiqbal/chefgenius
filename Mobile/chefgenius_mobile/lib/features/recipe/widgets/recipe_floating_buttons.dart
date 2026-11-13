import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/config/routes.dart';
import '../../../app/data/models/recipe_model.dart';
import '../../../app/data/providers/language_provider.dart';
import '../../community/screens/upload_post_screen.dart';

class RecipeFloatingButtons extends StatelessWidget {
  final Recipe recipe;

  const RecipeFloatingButtons({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tombol Tanya Chef Cei
        FloatingActionButton.extended(
          heroTag: "ask_chef_btn",
          onPressed: () {
            Navigator.pushNamed(
              context,
              AppRoutes.chatbotRoute,
              arguments: recipe,
            );
          },
          label: const Text("Tanya Chef Cei"),
          icon: const Icon(Icons.chat_bubble_outline_rounded),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
        const SizedBox(height: 10),
        // Tombol Pamerkan Hasil Masak
        FloatingActionButton.extended(
          heroTag: "upload_btn",
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UploadPostScreen(
                  initialRecipeId: recipe.id,
                  initialRecipeTitle: recipe.title,
                ),
              ),
            );
          },
          label: const Text("Pamerkan Hasil Masak"),
          icon: const Icon(Icons.camera_alt_rounded),
          backgroundColor: Colors.orange,
          elevation: 4,
        ),
        const SizedBox(height: 10),
        // Tombol Mulai Memasak
        if (recipe.steps.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: isDarkMode 
                  ? Border.all(color: Colors.white.withOpacity(0.3), width: 1.5)
                  : null,
            ),
            child: FloatingActionButton.extended(
              heroTag: "cook_btn",
              onPressed: () {
                Navigator.pushNamed(
                  context, 
                  AppRoutes.cookingModeRoute, 
                  arguments: recipe
                );
              },
              label: Text(lang.getText('rd_start_cooking'), style: const TextStyle(fontWeight: FontWeight.bold)),
              icon: const Icon(Icons.play_circle_fill_rounded),
              backgroundColor: isDarkMode 
                  ? Colors.grey[900] 
                  : Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              elevation: 4,
            ),
          ),
      ],
    );
  }
}
