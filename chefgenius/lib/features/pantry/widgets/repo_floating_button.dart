import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../recipe/screens/recipe_search_screen.dart';

class RepoFloatingButton extends StatelessWidget {
  final GlobalKey showcaseKey;
  final VoidCallback onReturn; // Callback setelah balik dari screen

  const RepoFloatingButton({
    super.key,
    required this.showcaseKey,
    required this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 0, // Nempel kanan
      top: MediaQuery.of(context).size.height * 0.4, // Posisi vertikal
      child: Showcase(
        key: showcaseKey,
        title: 'Gudang Resep',
        description: 'Mau cari resep manual tanpa bahan? Klik sini aja!',
        child: Material(
          color: Colors.orange.shade700,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            bottomLeft: Radius.circular(30),
          ),
          elevation: 5,
          child: InkWell(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30),
              bottomLeft: Radius.circular(30),
            ),
            onTap: () {
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const RecipeSearchScreen(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                ),
              ).then((_) => onReturn()); // Panggil callback update stats
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              child: const Icon(
                Icons.menu_book_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}