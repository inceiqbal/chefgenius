import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../app/config/chef_cei_assets.dart';
import '../../../app/data/models/recipe_model.dart';

class RecipeHeaderImage extends StatelessWidget {
  final Recipe recipe;

  const RecipeHeaderImage({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    if (recipe.isAiGenerated) {
      return GestureDetector(
        onTap: () => _showImageDialog(context, isAi: true),
        child: SizedBox(
          height: 350,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.orange.shade300,
                      Colors.orange.shade50,
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 80,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orangeAccent.withOpacity(0.4),
                        blurRadius: 60,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const Positioned(top: 100, left: 40, child: Icon(Icons.auto_awesome, color: Colors.amber, size: 28)),
              const Positioned(top: 140, right: 50, child: Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 20)),
              const Positioned(bottom: 120, left: 70, child: Icon(Icons.star_rounded, color: Colors.white, size: 16)),
              Positioned(
                bottom: 0,
                child: Image.asset(
                  ChefCeiAssets.presentasi, 
                  height: 280,
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                bottom: 30, 
                right: 24,  
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))
                    ]
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.amber, size: 16), 
                      const SizedBox(width: 6),
                      Text(
                        "Resep Spesial Chef Cei",
                        style: TextStyle(
                          color: Colors.deepOrange[900],
                          fontWeight: FontWeight.w900, 
                          fontSize: 12,
                          shadows: [
                            Shadow(
                              offset: const Offset(0, 1),
                              blurRadius: 2,
                              color: Colors.black.withOpacity(0.1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return GestureDetector(
        onTap: () => _showImageDialog(context, isAi: false),
        child: recipe.imageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: recipe.imageUrl,
                height: 350,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                    height: 350,
                    color: Colors.grey[300],
                    child: const Center(child: CircularProgressIndicator())),
                errorWidget: (context, url, error) => Image.asset(
                  ChefCeiAssets.berhasil,
                  height: 350,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            : Image.asset(
                ChefCeiAssets.berhasil,
                height: 350,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
      );
    }
  }

  void _showImageDialog(BuildContext context, {required bool isAi}) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: Scaffold(
              backgroundColor: Colors.black,
              body: Stack(
                children: [
                  // Fullscreen InteractiveViewer
                  Positioned.fill(
                    child: InteractiveViewer(
                      panEnabled: true,
                      scaleEnabled: true,
                      minScale: 0.5,
                      maxScale: 10.0, // Allow much larger zoom
                      child: Center(
                        child: isAi 
                          ? Image.asset(
                              ChefCeiAssets.presentasi, 
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                            )
                          : CachedNetworkImage(
                              imageUrl: recipe.imageUrl,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(color: Colors.white),
                              ),
                              errorWidget: (context, url, error) => const Icon(
                                Icons.broken_image, 
                                color: Colors.white, 
                                size: 50,
                              ),
                            ),
                      ),
                    ),
                  ),
                  // Close button
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 10,
                    right: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                  // Zoom hint
                  Positioned(
                    bottom: MediaQuery.of(context).padding.bottom + 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Cubit untuk zoom',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
