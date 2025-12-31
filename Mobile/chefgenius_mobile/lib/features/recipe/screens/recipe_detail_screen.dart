import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/data/models/recipe_model.dart';
import '../../../app/data/providers/connectivity_provider.dart';
import '../../../app/data/providers/language_provider.dart';
import '../../../app/data/providers/shopping_list_provider.dart';
import '../../../app/data/providers/recipe_rating_provider.dart';
import '../../../app/data/utils/ingredient_matcher.dart';
import '../widgets/recipe_header_image.dart';
import '../widgets/recipe_info_section.dart';
import '../widgets/recipe_ingredients_list.dart';
import '../widgets/recipe_steps_list.dart';
import '../widgets/recipe_floating_buttons.dart';
import '../widgets/recipe_rating_widget.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
    // Share feature removed for recipe/book UI
  bool isFavorite = false;
  bool isLoading = true;
  Map<String, IngredientMatchStatus> ingredientStatuses = {};
  int missingCount = 0;
  bool isCheckingStock = true;
  bool isAddingToCart = false;

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus();
    _checkPantryStock();
    _loadRating();
  }

  void _loadRating() {
    // Load rating from provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecipeRatingProvider>().loadRating(widget.recipe.id);
    });
  }

  Future<void> _checkFavoriteStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final response = await Supabase.instance.client
            .from('favorite_recipes')
            .select()
            .eq('user_id', user.id)
            .eq('recipe_id', widget.recipe.id)
            .maybeSingle();

        if (mounted) {
          setState(() {
            isFavorite = response != null;
            isLoading = false;
          });
        }
      } catch (e) {
        debugPrint('Error checking favorite status: $e');
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final user = Supabase.instance.client.auth.currentUser;
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.getText('recipe_login_required'))),
      );
      return;
    }

    setState(() {
      isFavorite = !isFavorite;
    });

    try {
      if (isFavorite) {
        await Supabase.instance.client.from('favorite_recipes').insert({
          'user_id': user.id,
          'recipe_id': widget.recipe.id,
        });
      } else {
        await Supabase.instance.client
            .from('favorite_recipes')
            .delete()
            .eq('user_id', user.id)
            .eq('recipe_id', widget.recipe.id);
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      if (mounted) {
        setState(() {
          isFavorite = !isFavorite;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.getText('recipe_fav_fail'))),
        );
      }
    }
  }

  Future<void> _checkPantryStock() async {
    if (!mounted) return;
    
    setState(() {
      isCheckingStock = true;
    });

    try {
      final userEmail = Supabase.instance.client.auth.currentUser?.email ?? 'guest';
      final boxName = 'pantry_$userEmail';
      
      Box box;
      if (Hive.isBoxOpen(boxName)) {
        box = Hive.box<String>(boxName);
      } else {
        box = await Hive.openBox<String>(boxName);
      }
      
      List<String> pantryItems = box.values.cast<String>().toList();

      Map<String, IngredientMatchStatus> tempStatuses = {};
      int tempMissing = 0;

      for (var ingredient in widget.recipe.allIngredients) {
        IngredientMatchStatus status = IngredientMatcher.checkStatus(ingredient.name, pantryItems);
        tempStatuses[ingredient.name] = status;
        
        if (status == IngredientMatchStatus.missing) {
          tempMissing++;
        }
      }

      if (mounted) {
        setState(() {
          ingredientStatuses = tempStatuses;
          missingCount = tempMissing;
          isCheckingStock = false;
        });
      }
    } catch (e) {
      debugPrint("Error checking pantry: $e");
      if (mounted) {
        setState(() {
          isCheckingStock = false;
        });
      }
    }
  }

  Future<void> _addMissingIngredientsToCart() async {
    setState(() {
      isAddingToCart = true;
    });

    try {
      final shoppingProvider = Provider.of<ShoppingListProvider>(context, listen: false);
      final connectivityProvider = Provider.of<ConnectivityProvider>(context, listen: false);
      final lang = Provider.of<LanguageProvider>(context, listen: false);
      int addedCount = 0;
      List<String> missingIngredients = [];

      for (var ingredient in widget.recipe.allIngredients) {
        if (ingredientStatuses[ingredient.name] == IngredientMatchStatus.missing) {
          missingIngredients.add(ingredient.name);
          addedCount++;
        }
      }

      if (missingIngredients.isNotEmpty) {
        await shoppingProvider.addIngredientsFromRecipe(missingIngredients, widget.recipe.title, connectivityProvider.isOffline);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.getText('rd_added_cart_msg').replaceAll('@count', '$addedCount')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error adding to cart: $e");
      if (mounted) {
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.getText('recipe_cart_fail'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isAddingToCart = false;
        });
      }
    }
  }

  void _copyIngredientsToClipboard() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    String text = "${lang.getText('rd_ingredients_for')} ${widget.recipe.title}:\n\n";
    
    for (var ingredient in widget.recipe.allIngredients) {
      text += "- ${ingredient.quantity} ${ingredient.name}\n";
    }

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(lang.getText('rd_copied_msg'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 350.0,
            floating: false,
            pinned: true,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : Colors.white,
                  ),
                  onPressed: _toggleFavorite,
                ),
              ),
              // Share button removed from recipe UI
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: RecipeHeaderImage(recipe: widget.recipe),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title & Rating
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            widget.recipe.title,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).brightness == Brightness.dark 
                                      ? Colors.white 
                                      : Theme.of(context).primaryColor,
                                ),
                          ),
                        ),
                        Consumer<RecipeRatingProvider>(
                          builder: (context, ratingProvider, child) {
                            return RecipeRatingWidget(
                              averageRating: ratingProvider.getAverageRating(widget.recipe.id),
                              ratingCount: ratingProvider.getRatingCount(widget.recipe.id),
                              userRating: ratingProvider.getUserRating(widget.recipe.id),
                              isLoading: ratingProvider.isLoading(widget.recipe.id),
                              onRatingSubmit: (rating) async {
                                final success = await ratingProvider.submitRating(widget.recipe.id, rating);
                                if (mounted && success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Terima kasih atas penilaian Anda!'),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  );
                                }
                              },
                              onRatingCancel: () async {
                                final success = await ratingProvider.deleteRating(widget.recipe.id);
                                if (mounted && success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Penilaian dibatalkan'),
                                      backgroundColor: Colors.orange,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    const Divider(height: 24),

                    // Info Sections
                    RecipeInfoSection(
                      title: lang.getText('rd_desc'),
                      data: widget.recipe.description,
                      withDivider: true,
                    ),

                    RecipeInfoSection(
                      title: lang.getText('rd_time'),
                      data: widget.recipe.duration,
                      icon: Icons.timer_outlined,
                      iconColor: Colors.orange,
                    ),

                    RecipeInfoSection(
                      title: lang.getText('rd_servings'),
                      data: widget.recipe.servings,
                      icon: Icons.people_outline,
                      iconColor: Colors.blue,
                    ),

                    if (widget.recipe.halalStatus.isNotEmpty)
                      RecipeInfoSection(
                        title: "Status Halal",
                        data: widget.recipe.halalStatus,
                        icon: Icons.verified_user_outlined,
                        iconColor: Colors.green,
                      ),

                    // Ingredients List
                    RecipeIngredientsList(
                      recipe: widget.recipe,
                      ingredientStatuses: ingredientStatuses,
                      isCheckingStock: isCheckingStock,
                      missingCount: missingCount,
                      isAddingToCart: isAddingToCart,
                      onAddMissingToCart: _addMissingIngredientsToCart,
                      onCopyIngredients: _copyIngredientsToClipboard,
                    ),

                    // Steps List
                    RecipeStepsList(steps: widget.recipe.steps),

                    const SizedBox(height: 160), // Space for 2 FABs
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
      floatingActionButton: RecipeFloatingButtons(recipe: widget.recipe),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
