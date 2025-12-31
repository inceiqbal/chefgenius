import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart'; 
import '../../../app/widgets/custom_app_bar.dart';
import '../../../app/config/chef_cei_assets.dart'; 
import 'package:intl/intl.dart'; 
import 'package:chefgenius/features/recipe/screens/recipe_detail_screen.dart';
import 'package:chefgenius/app/data/models/recipe_model.dart';
import '../../../app/data/providers/language_provider.dart'; 

class CookingHistoryScreen extends StatefulWidget {
  const CookingHistoryScreen({super.key});

  @override
  State<CookingHistoryScreen> createState() => _CookingHistoryScreenState();
}

class _CookingHistoryScreenState extends State<CookingHistoryScreen> {
  final supabase = Supabase.instance.client;
  Map<String, List<Map<String, dynamic>>> _groupedHistory = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    // final lang = Provider.of<LanguageProvider>(context, listen: false);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('cooking_history')
          .select()
          .eq('user_id', userId)
          .order('cooked_at', ascending: false);

      if (mounted) {
        Map<String, List<Map<String, dynamic>>> tempGroup = {};
        
        for (var item in response) {
          String title = item['recipe_title'] ?? 'Tanpa Nama';
          if (!tempGroup.containsKey(title)) {
            tempGroup[title] = [];
          }
          tempGroup[title]!.add(item);
        }

        setState(() {
          _groupedHistory = tempGroup;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.getText('history_load_fail_msg'))),
        );
      }
    }
  }

  // --- FITUR HAPUS SEMUA ---
  Future<void> _confirmDeleteAll() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Semua Riwayat?"),
        content: const Text("Yakin mau hapus semua kenangan masak kita? Nanti Cei lupa lho kamu udah masak apa aja! 🥺"), 
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang.getText('cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAllHistory();
            },
            child: Text(lang.getText('delete_btn'), style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAllHistory() async {
    // final lang = Provider.of<LanguageProvider>(context, listen: false);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      await supabase
          .from('cooking_history')
          .delete()
          .eq('user_id', userId);

      if (mounted) {
        setState(() {
          _groupedHistory.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Oke, riwayat masak udah bersih! Siap mulai lembaran baru! ✨"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.getText('history_clear_fail')), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- FITUR HAPUS PER RESEP (SWIPE) ---
  Future<void> _deleteRecipeHistory(String recipeTitle) async {
    // final lang = Provider.of<LanguageProvider>(context, listen: false);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      await supabase
          .from('cooking_history')
          .delete()
          .eq('user_id', userId)
          .eq('recipe_title', recipeTitle);

      if (mounted) {
        setState(() {
          _groupedHistory.remove(recipeTitle);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Oke, riwayat masak $recipeTitle udah dihapus! 👋"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        _loadHistory();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.getText('history_delete_item_fail')), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _getValidImageUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return '';
    if (rawUrl.startsWith('http')) return rawUrl;
    try {
      final filename = rawUrl.split('/').last; 
      return supabase.storage
          .from('recipe-images')
          .getPublicUrl('Food Images/$filename');
    } catch (e) {
      return '';
    }
  }

  Future<void> _openRecipeDetail(int? recipeId, String title, dynamic aiData, String? fallbackImageUrl) async {
    // final lang = Provider.of<LanguageProvider>(context, listen: false);
    try {
      showDialog(
        context: context, 
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator())
      );

      Recipe? recipeToOpen;
      bool isFavorited = false;
      final userId = supabase.auth.currentUser?.id;

      if ((recipeId == null || recipeId == 0) && aiData != null) {
         try {
            final recipeMap = Map<String, dynamic>.from(aiData as Map);
            recipeToOpen = Recipe.fromJson(recipeMap, isGeneratedByAi: true);

            // Cek status favorit untuk resep AI
            if (userId != null) {
               final favResponse = await supabase
                   .from('ai_favorite_recipes')
                   .select('id')
                   .eq('user_id', userId)
                   .eq('title', recipeToOpen.title)
                   .maybeSingle();
               if (favResponse != null) isFavorited = true;
            }
         } catch (e) {
            debugPrint("Gagal parsing resep AI: $e");
         }
      } 
      else if (recipeId != null && recipeId > 0) {
         final response = await supabase
            .from('recipes')
            .select()
            .eq('id', recipeId)
            .maybeSingle();
         
         if (response != null) {
            recipeToOpen = Recipe.fromJson(response);

            // Cek status favorit untuk resep biasa
            if (userId != null) {
               final favResponse = await supabase
                   .from('favorite_recipes')
                   .select('id')
                   .eq('user_id', userId)
                   .eq('recipe_id', recipeId)
                   .maybeSingle();
               if (favResponse != null) isFavorited = true;
            }
         }
      }

      if (!mounted) return;
      Navigator.pop(context); 

      if (recipeToOpen != null) {
         // Prioritaskan gambar dari history (fallbackImageUrl) jika ada
         // Ini memastikan gambar yang muncul di detail SAMA dengan yang di list
         if (fallbackImageUrl != null && fallbackImageUrl.isNotEmpty) {
             recipeToOpen.imageUrl = fallbackImageUrl;
         } else {
             recipeToOpen.imageUrl = _getValidImageUrl(recipeToOpen.imageUrl);
         }

         recipeToOpen.isFavorite = isFavorited;

         Navigator.push(
           context,
           MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipeToOpen!)),
         );
      } else {
         showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Resepnya Ilang?"), 
              content: const Text("Waduh, resep ini kayaknya udah gak ada atau datanya rusak. Maaf ya! 😔"), 
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Oke"))],
            )
         );
      }

    } catch (e) {
      if (mounted) {
         final lang = Provider.of<LanguageProvider>(context, listen: false);
         if (Navigator.canPop(context)) Navigator.pop(context);
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(lang.getText('history_open_fail').replaceAll('@error', e.toString())), backgroundColor: Colors.red),
         );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: lang.getText('history_title'),
        actions: [
          if (_groupedHistory.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
              tooltip: lang.getText('history_delete_all'),
              onPressed: _confirmDeleteAll,
            )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groupedHistory.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                          ChefCeiAssets.kosong, 
                          width: 200, 
                          fit: BoxFit.contain
                      ),
                      const SizedBox(height: 16),
                      Text(lang.getText('history_empty'),
                          style: const TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _groupedHistory.length,
                  itemBuilder: (context, index) {
                    String title = _groupedHistory.keys.elementAt(index);
                    List<Map<String, dynamic>> historyItems = _groupedHistory[title]!;
                    
                    var mainItem = historyItems.first;
                    String rawImg = mainItem['recipe_image_url'] ?? '';
                    String imageUrl = _getValidImageUrl(rawImg);

                    int? recipeId = mainItem['recipe_id'] as int?;
                    dynamic aiRecipeData = mainItem['recipe_details']; 
                    bool isAiRecipe = (recipeId == 0 || recipeId == null);
                    int totalCooked = historyItems.length;
                    bool canOpen = (!isAiRecipe) || (isAiRecipe && aiRecipeData != null);

                    return Dismissible(
                      key: Key(title),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20.0),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white, size: 32),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text("Hapus Riwayat Ini?"),
                              content: Text("Yakin mau hapus riwayat masak $title? 🗑️"),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: Text(lang.getText('cancel')),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: Text(lang.getText('delete_btn'), style: const TextStyle(color: Colors.red)),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      onDismissed: (direction) {
                        _deleteRecipeHistory(title);
                      },
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        clipBehavior: Clip.antiAlias,
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.all(12),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              // --- UPDATE: LOGIKA GAMBAR BARU ---
                              child: imageUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorWidget: (context, url, error) => Image.asset(
                                        'assets/images/Chef_Cei/checeipresentasi.png',
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Image.asset(
                                      'assets/images/Chef_Cei/checeipresentasi.png', // Gambar pengganti icon
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                    ),
                              // ----------------------------------
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isAiRecipe) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      "AI",
                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ]
                              ],
                            ),
                            subtitle: Text(
                              "${lang.getText('history_cooked_times').replaceAll('@count', totalCooked.toString())} • ${lang.getText('history_last_cooked').replaceAll('@date', _formatDate(mainItem['cooked_at'], lang))}",
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                            children: [
                              const Divider(height: 1, indent: 16, endIndent: 16),
                              ...historyItems.map((hItem) {
                                 return ListTile(
                                   dense: true,
                                   visualDensity: VisualDensity.compact,
                                   contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                                   leading: const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                   title: Text(_formatDateFull(hItem['cooked_at'], lang), style: const TextStyle(fontSize: 13)),
                                   trailing: const Icon(Icons.check_circle, size: 16, color: Colors.green),
                                 );
                              }).toList(),

                              if (canOpen)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: Builder(builder: (ctx) {
                                      final isDark = Theme.of(ctx).brightness == Brightness.dark;
                                      final fg = isDark ? Colors.white : Theme.of(ctx).primaryColor;
                                      final sideColor = isDark ? Colors.white.withOpacity(0.15) : Theme.of(ctx).primaryColor;
                                      return OutlinedButton.icon(
                                        icon: const Icon(Icons.restaurant_menu, size: 18),
                                        label: Text(lang.getText('history_open_recipe')),
                                        onPressed: () => _openRecipeDetail(recipeId, title, aiRecipeData, imageUrl),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: fg,
                                          side: BorderSide(color: sideColor),
                                        ),
                                      );
                                    }),
                                  ),
                                )
                              else 
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[50],
                                      borderRadius: BorderRadius.circular(8)
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                                        const SizedBox(width: 8),
                                        Text(lang.getText('history_old_data'), style: const TextStyle(fontSize: 12, color: Colors.orange)),
                                      ],
                                    ),
                                  ),
                                )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  String _formatDate(String isoString, LanguageProvider lang) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      return DateFormat('d MMMM yyyy', lang.appLocale.toString()).format(date);
    } catch (e) {
      return "-";
    }
  }

  String _formatDateFull(String isoString, LanguageProvider lang) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      return DateFormat('d MMMM yyyy, HH:mm', lang.appLocale.toString()).format(date);
    } catch (e) {
      return "-";
    }
  }
}