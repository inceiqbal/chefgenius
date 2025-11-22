import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Buat fitur Copy Clipboard
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart'; // Import Share

import '../../../app/data/models/recipe_model.dart';
import '../../../app/widgets/custom_app_bar.dart';
import '../../../app/data/providers/connectivity_provider.dart';
import '../../../app/widgets/offline_banner.dart';
import '../../../app/config/routes.dart';
import '../../../app/config/chef_cei_assets.dart';
// FIX IMPORT: Sesuaikan dengan lokasi file IngredientMatcher
import 'package:chefgenius/app/data/utils/ingredient_matcher.dart';
import '../../../app/data/providers/shopping_list_provider.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;
  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late bool _isFavorited;
  bool _isLoadingFavorite = true;
  int? _aiFavoriteDbId;
  final supabase = Supabase.instance.client;

  // --- SMART SHOPPING LIST VARIABLES ---
  late Box<String> _pantryBox;
  bool _isCheckingStock = true;
  List<String> _missingIngredients = [];
  bool _isAddingToCart = false;

  // Info Nutrisi & Deskripsi Bersih
  String? _extractedNutritionInfo;
  String _cleanDescription = "";

  @override
  void initState() {
    super.initState();
    _isFavorited = widget.recipe.isFavorite;
    _isLoadingFavorite = false;

    _parseNutritionFromDescription();

    if (widget.recipe.isAiGenerated && _isFavorited) {
      _getAiFavoriteId();
    }

    _checkPantryStock();
  }

  // --- LOGIKA SHARE RESEP ---
  void _shareRecipe() {
    final recipe = widget.recipe;
    final StringBuffer sb = StringBuffer();

    // 1. Judul Keren
    sb.writeln('🍳 *${recipe.title}*');
    sb.writeln('---------------------------');
    
    // 2. Deskripsi & Nutrisi
    if (_cleanDescription.isNotEmpty) {
      sb.writeln(_cleanDescription);
      sb.writeln('');
    }
    
    if (_extractedNutritionInfo != null) {
      sb.writeln('💪 *Info Nutrisi:*');
      sb.writeln(_extractedNutritionInfo);
      sb.writeln('');
    }

    // 3. Detail Waktu & Porsi
    sb.writeln('⏳ Waktu: ${recipe.duration}');
    sb.writeln('🍽️ Porsi: ${recipe.servings}');
    sb.writeln('✅ Status: ${recipe.halalStatus}');
    sb.writeln('');

    // 4. Bahan-bahan
    sb.writeln('🛒 *Bahan-bahan:*');
    for (var ingredient in recipe.allIngredients) {
      sb.writeln('• ${ingredient.quantity} ${ingredient.name}'.trim());
    }
    sb.writeln('');

    // 5. Langkah-langkah
    sb.writeln('👩‍🍳 *Cara Membuat:*');
    for (var i = 0; i < recipe.steps.length; i++) {
      sb.writeln('${i + 1}. ${recipe.steps[i]}');
    }
    sb.writeln('');
    
    // 6. Footer Promosi
    sb.writeln('📲 *Dibuat dengan Chef Genius App*');
    sb.writeln('Download sekarang dan jadi koki handal!');

    // Panggil Native Share
    Share.share(sb.toString());
  }
  // ----------------------------------------

  Future<void> _checkPantryStock() async {
    try {
      final userEmail = supabase.auth.currentUser?.email ?? 'guest';
      
      if (!Hive.isBoxOpen('pantry_$userEmail')) {
        _pantryBox = await Hive.openBox<String>('pantry_$userEmail');
      } else {
        _pantryBox = Hive.box<String>('pantry_$userEmail');
      }
      
      if (!Hive.isBoxOpen('shopping_$userEmail')) {
      } else {
      }

      // Ambil semua bahan di pantry (Raw List)
      final List<String> pantryItems = _pantryBox.values.toList();
      final recipeIngredients = widget.recipe.allIngredients;
      
      List<String> missing = [];

      for (var ingredient in recipeIngredients) {
        // --- LOGIKA MATCHING PINTAR ---
        bool isAvailable = IngredientMatcher.isMatch(ingredient.name, pantryItems);

        if (!isAvailable) {
          missing.add(ingredient.name);
        }
      }

      if (mounted) {
        setState(() {
          _missingIngredients = missing;
          _isCheckingStock = false;
        });
      }
    } catch (e) {
      debugPrint("Gagal cek stok pantry: $e");
      if (mounted) setState(() => _isCheckingStock = false);
    }
  }

  Future<void> _addMissingToShoppingList() async {
    if (_missingIngredients.isEmpty) return;
    
    setState(() => _isAddingToCart = true);

    try {
      final isOffline = context.read<ConnectivityProvider>().isOffline;
      
      // UPDATE: PAKE PROVIDER BIAR GROUPING JALAN
      await context.read<ShoppingListProvider>().addIngredientsFromRecipe(
        _missingIngredients, 
        widget.recipe.title, // Kirim judul resep
        isOffline
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Berhasil nambah ${_missingIngredients.length} bahan ke daftar belanja!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error add to cart: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal update daftar belanja.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  void _parseNutritionFromDescription() {
    String text = widget.recipe.description;
    
    final regex = RegExp(r'\(Est:.*?\)', caseSensitive: false);
    final match = regex.firstMatch(text);

    if (match != null) {
      setState(() {
        _extractedNutritionInfo = match.group(0)
            ?.replaceAll('(', '')
            .replaceAll(')', '')
            .trim();
        
        _cleanDescription = text.replaceAll(regex, '').trim();
      });
    } else {
      setState(() {
        _cleanDescription = text;
      });
    }
  }

  Future<void> _getAiFavoriteId() async {
    if (!mounted || context.read<ConnectivityProvider>().isOffline) return;
    
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('ai_favorite_recipes')
          .select('id')
          .eq('user_id', userId)
          .eq('title', widget.recipe.title)
          .maybeSingle();
          
      if (response != null) {
         _aiFavoriteDbId = response['id'];
      }
    } catch (e) {
      debugPrint("Gagal ngambil _aiFavoriteDbId: $e");
    }
  }

  Future<void> _toggleFavorite() async {
    if (context.read<ConnectivityProvider>().isOffline) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kamu lagi offline! Gak bisa nambah/hapus favorit, Sob.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    setState(() => _isLoadingFavorite = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        scaffoldMessenger.showSnackBar(const SnackBar(
            content: Text('Anda harus login untuk menambahkan favorit!')));
        if (mounted) {
          setState(() => _isLoadingFavorite = false);
        }
        return;
      }

      String successMessage = '';

      if (widget.recipe.isAiGenerated) {
        if (_isFavorited) {
          if (_aiFavoriteDbId == null) {
            await _getAiFavoriteId();
          }
          
          if (_aiFavoriteDbId == null) throw Exception("ID resep AI tidak ditemukan");

          await supabase
              .from('ai_favorite_recipes')
              .delete()
              .eq('id', _aiFavoriteDbId!);

          successMessage = '${widget.recipe.title} dihapus dari favorit.';
          if (mounted) {
            setState(() {
              _isFavorited = false;
              _aiFavoriteDbId = null;
            });
          }
        } else {
          final dataToInsert = {
            'user_id': userId,
            'title': widget.recipe.title,
            'ingredients': widget.recipe.allIngredients
                .map((e) => {'name': e.name, 'quantity': e.quantity})
                .toList(),
            'steps': widget.recipe.steps,
            'image_url': null,
            'duration': widget.recipe.duration,
            'servings': widget.recipe.servings,
            'halal_status': widget.recipe.halalStatus,
            'description': widget.recipe.description, 
          };

          final response = await supabase
              .from('ai_favorite_recipes')
              .insert(dataToInsert)
              .select('id')
              .single();

          successMessage = '${widget.recipe.title} ditambahkan ke favorit!';
          if (mounted) {
            setState(() {
              _isFavorited = true;
              _aiFavoriteDbId = response['id'];
            });
          }
        }
      } else {
        if (_isFavorited) {
          await supabase
              .from('favorite_recipes')
              .delete()
              .match({'user_id': userId, 'recipe_id': widget.recipe.id});

          successMessage = '${widget.recipe.title} dihapus dari favorit.';
          if (mounted) {
            setState(() {
              _isFavorited = false;
              widget.recipe.isFavorite = false;
            });
          }
        } else {
          await supabase
              .from('favorite_recipes')
              .insert({'user_id': userId, 'recipe_id': widget.recipe.id});

          successMessage = '${widget.recipe.title} ditambahkan ke favorit!';
          if (mounted) {
            setState(() {
              _isFavorited = true;
              widget.recipe.isFavorite = true;
            });
          }
        }
      }

      scaffoldMessenger.showSnackBar(SnackBar(
        content: Text(successMessage),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
            content: Text('Gagal ngubah favorit: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingFavorite = false);
      }
    }
  }

  void _copyIngredientsToClipboard() {
    final ingredientsText = widget.recipe.allIngredients
        .map((e) => "- ${e.quantity} ${e.name}")
        .join("\n");
    
    final textToCopy = "Bahan Belanja untuk ${widget.recipe.title}:\n$ingredientsText";
    
    Clipboard.setData(ClipboardData(text: textToCopy));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Daftar bahan disalin! Siap kirim ke WA.")),
    );
  }

  Widget _buildInfoSection(
      {required String title, required String data, IconData? icon, Color? iconColor}) {
    if (data.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (icon != null)
            Row(
              children: [
                Icon(icon, size: 18, color: iconColor ?? Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data,
                    style:
                        Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                ),
              ],
            )
          else
            Text(
              data,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
              textAlign: TextAlign.justify,
            ),
          const Divider(height: 24),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isHalal = widget.recipe.halalStatus.toLowerCase() == 'halal';
    final isOffline = context.watch<ConnectivityProvider>().isOffline;

    return Scaffold(
      extendBodyBehindAppBar: true, // Biar gambar bisa di belakang AppBar
      appBar: CustomAppBar(
        title: 'Detail Resep',
        backgroundColor: Colors.transparent, 
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: "Bagikan Resep",
            onPressed: _shareRecipe, 
          ),
          _isLoadingFavorite
              ? const Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: Icon(
                    _isFavorited ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorited ? Colors.redAccent : (isOffline ? Colors.grey : null),
                  ),
                  onPressed: isOffline ? null : _toggleFavorite,
                  tooltip: isOffline 
                      ? 'Offline (Gak bisa favorit)' 
                      : (_isFavorited ? 'Hapus dari Favorit' : 'Tambah ke Favorit'),
                ),
        ],
      ),
      floatingActionButton: widget.recipe.steps.isNotEmpty 
        ? FloatingActionButton.extended(
            onPressed: () {
              Navigator.pushNamed(
                context, 
                AppRoutes.cookingModeRoute, 
                arguments: widget.recipe
              );
            },
            label: const Text('Mulai Masak', style: TextStyle(fontWeight: FontWeight.bold)),
            icon: const Icon(Icons.play_circle_fill),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          )
        : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      
      body: SingleChildScrollView(
        padding: EdgeInsets.zero, // Hapus padding default biar mepet atas
        child: Column(
          children: [
            const OfflineBanner(),
            
            // --- HEADER GAMBAR (VISUAL CHEF CEI & LOGIKA BARU) ---
            if (widget.recipe.isAiGenerated)
              SizedBox(
                height: 320, // Tinggi header ditambah dikit
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 1. Background Gradient Biru Muda
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.blue.shade200,
                            Colors.blue.shade50,
                          ],
                        ),
                      ),
                    ),
                    
                    // 2. Efek Lingkaran Cahaya (Glow)
                    Positioned(
                      top: 60,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueAccent.withOpacity(0.4),
                              blurRadius: 50,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 3. Bintang-bintang Magic
                    const Positioned(top: 80, left: 50, child: Icon(Icons.auto_awesome, color: Colors.amber, size: 24)),
                    const Positioned(top: 120, right: 60, child: Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 18)),
                    const Positioned(bottom: 100, left: 80, child: Icon(Icons.star, color: Colors.white, size: 14)),

                    // 4. Gambar Chef Cei Presentasi
                    Positioned(
                      bottom: 0,
                      child: Image.asset(
                        ChefCeiAssets.presentasi, 
                        height: 250,
                        fit: BoxFit.contain,
                      ),
                    ),

                    // 5. LABEL MINIMALIS (POJOK KANAN BAWAH - UPDATED)
                    Positioned(
                      bottom: 16, 
                      right: 24,  
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome, color: Colors.amber, size: 16), 
                          const SizedBox(width: 6),
                          Text(
                            "Resep Spesial Chef Cei",
                            style: TextStyle(
                              color: const Color(0xFF1A237E), // Biru Tua
                              fontWeight: FontWeight.w900, // Tebal
                              fontSize: 12,
                              shadows: [
                                Shadow(
                                  offset: const Offset(1, 1),
                                  blurRadius: 4,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              // Header Gambar Biasa (Untuk Resep Non-AI)
              CachedNetworkImage(
                imageUrl: widget.recipe.imageUrl,
                height: 300,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                    height: 300,
                    color: Colors.grey[300],
                    child: const Center(child: CircularProgressIndicator())),
                errorWidget: (context, url, error) => Container(
                    height: 300,
                    color: Colors.grey[300],
                    child: const Center(
                        child: Icon(Icons.broken_image,
                            size: 100, color: Colors.grey))),
              ),

            // --- KONTEN RESEP (Rounded & Translate) ---
            Transform.translate(
              offset: const Offset(0, -20), // Geser ke atas biar numpuk header
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor, 
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), 
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    )
                  ]
                ),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.recipe.title,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    
                    // ... (Nutrisi, Info, dll) ...
                    
                    if (_extractedNutritionInfo != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
                                const SizedBox(width: 8),
                                Text("Info Nutrisi & Diet", 
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold, 
                                    color: Colors.green[800]
                                  )
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _extractedNutritionInfo!, 
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)
                            ),
                          ],
                        ),
                      ),
                    
                    _buildInfoSection(
                      title: 'Status Makanan',
                      data: widget.recipe.halalStatus,
                      icon: isHalal ? Icons.check_circle : Icons.warning_amber_rounded,
                      iconColor: isHalal ? Colors.green : Colors.redAccent,
                    ),

                    _buildInfoSection(
                      title: 'Deskripsi',
                      data: _cleanDescription,
                    ),

                    Row(
                      children: [
                        Expanded(
                           child: _buildInfoSection(
                            title: 'Waktu',
                            data: widget.recipe.duration,
                            icon: Icons.timer_outlined,
                          ),
                        ),
                        Expanded(
                          child: _buildInfoSection(
                            title: 'Porsi',
                            data: widget.recipe.servings,
                            icon: Icons.restaurant_menu_outlined,
                          ),
                        ),
                      ],
                    ),
                    
                    if (widget.recipe.allIngredients.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Bahan-bahan',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            onPressed: _copyIngredientsToClipboard, 
                            icon: const Icon(Icons.copy, size: 20),
                            tooltip: "Salin daftar bahan",
                          )
                        ],
                      ),
                      const SizedBox(height: 8),

                      // SMART STOCK CHECKER UI
                      if (_isCheckingStock)
                         const Center(child: Padding(padding: EdgeInsets.all(8.0), child: LinearProgressIndicator()))
                      else ...[
                         if (_missingIngredients.isNotEmpty)
                           Container(
                             margin: const EdgeInsets.only(bottom: 16),
                             padding: const EdgeInsets.all(12),
                             decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1), 
                                borderRadius: BorderRadius.circular(12), 
                                border: Border.all(color: Colors.red.withOpacity(0.3))
                             ),
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Row(
                                   children: [
                                     const Icon(Icons.shopping_cart_checkout, color: Colors.red, size: 20), 
                                     const SizedBox(width: 8), 
                                     const Text("Bahan Kurang:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))
                                   ]
                                 ),
                                 const SizedBox(height: 8),
                                 Text("Kamu kekurangan ${_missingIngredients.length} bahan. Cek stok dapurmu!", style: const TextStyle(fontSize: 12)),
                                 const SizedBox(height: 12),
                                 SizedBox(
                                   width: double.infinity,
                                   child: ElevatedButton.icon(
                                     onPressed: _isAddingToCart ? null : _addMissingToShoppingList,
                                     icon: _isAddingToCart 
                                       ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                       : const Icon(Icons.add_shopping_cart, size: 16),
                                     label: Text(_isAddingToCart ? "Menyimpan..." : "Masukan ke Keranjang Belanja"),
                                     style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                                   ),
                                 )
                              ],
                            ),
                           ),
                      ],

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widget.recipe.allIngredients
                            .map((ingredient) {
                              bool isMissing = _missingIngredients.contains(ingredient.name);
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      isMissing ? Icons.cancel_outlined : Icons.check_circle_outline,
                                      size: 20,
                                      color: isMissing ? Colors.red : Theme.of(context).primaryColor
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '${ingredient.quantity} ${ingredient.name}'.trim(),
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          color: isMissing ? Colors.red[800] : null,
                                          fontWeight: isMissing ? FontWeight.w500 : FontWeight.normal
                                        ),
                                      ),
                                    ),
                                    if (isMissing)
                                      const Text("Kurang", style: TextStyle(fontSize: 10, color: Colors.red, fontStyle: FontStyle.italic))
                                  ],
                                ),
                              );
                            })
                            .toList(),
                      ),
                      const Divider(height: 24),
                    ],
                    if (widget.recipe.steps.isNotEmpty) ...[
                      Text(
                        'Langkah-langkah',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Column(
                        children: widget.recipe.steps.asMap().entries.map((entry) {
                          int index = entry.key;
                          String step = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    step,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(height: 1.5),
                                    textAlign: TextAlign.justify,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 80), // Padding bawah buat FAB
          ],
        ),
      ),
    );
  }
}