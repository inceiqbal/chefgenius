import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../app/widgets/custom_app_bar.dart';
import '../../../app/config/chef_cei_assets.dart'; 
import 'package:intl/intl.dart'; 
import 'package:chefgenius/features/recipe/screens/recipe_detail_screen.dart';
import 'package:chefgenius/app/data/models/recipe_model.dart';

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
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal muat riwayat: $e')),
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

  Future<void> _openRecipeDetail(int? recipeId, String title, dynamic aiData) async {
    try {
      showDialog(
        context: context, 
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator())
      );

      Recipe? recipeToOpen;

      if ((recipeId == null || recipeId == 0) && aiData != null) {
         try {
            final recipeMap = Map<String, dynamic>.from(aiData as Map);
            recipeToOpen = Recipe.fromJson(recipeMap, isGeneratedByAi: true);
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
         }
      }

      if (!mounted) return;
      Navigator.pop(context); 

      if (recipeToOpen != null) {
         recipeToOpen.imageUrl = _getValidImageUrl(recipeToOpen.imageUrl);
         Navigator.push(
           context,
           MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipeToOpen!)),
         );
      } else {
         showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Resep Hilang"),
              content: const Text("Yah, data resep ini udah gak ada di database atau belum tersimpan lengkap."),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Oke"))],
            )
         );
      }

    } catch (e) {
      if (mounted) {
         if (Navigator.canPop(context)) Navigator.pop(context);
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Gagal membuka: $e"), backgroundColor: Colors.red),
         );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Jejak Kuliner'),
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
                      const Text('Belum ada jejak masak.',
                          style: TextStyle(color: Colors.grey, fontSize: 16)),
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

                    return Card(
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
                            child: imageUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) => Container(
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.broken_image, size: 20, color: Colors.grey),
                                    ),
                                  )
                                : Container(
                                    width: 60,
                                    height: 60,
                                    color: isAiRecipe ? Colors.blue[50] : Colors.orange[50],
                                    child: Icon(
                                      isAiRecipe ? Icons.psychology : Icons.restaurant,
                                      color: isAiRecipe ? Colors.blue : Colors.orange,
                                    ),
                                  ),
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
                            "Dimasak $totalCooked kali • Terakhir: ${_formatDate(mainItem['cooked_at'])}",
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
                                 title: Text(_formatDateFull(hItem['cooked_at']), style: const TextStyle(fontSize: 13)),
                                 trailing: const Icon(Icons.check_circle, size: 16, color: Colors.green),
                               );
                            }).toList(),

                            if (canOpen)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.restaurant_menu, size: 18),
                                    label: const Text("Buka Resep"),
                                    onPressed: () => _openRecipeDetail(recipeId, title, aiRecipeData),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Theme.of(context).primaryColor,
                                      side: BorderSide(color: Theme.of(context).primaryColor),
                                    ),
                                  ),
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
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.info_outline, size: 16, color: Colors.orange),
                                      SizedBox(width: 8),
                                      Text("Data resep lama tidak tersimpan.", style: TextStyle(fontSize: 12, color: Colors.orange)),
                                    ],
                                  ),
                                ),
                              )
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  // --- FORMAT TANGGAL PAKE INTL (LEBIH PROFESIONAL) ---
  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      // Format: 20 Nov 2025
      return DateFormat('d MMMM yyyy', 'id_ID').format(date);
    } catch (e) {
      return "-";
    }
  }

  String _formatDateFull(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      // Format: 20 November 2025, 14:30
      return DateFormat('d MMMM yyyy, HH:mm', 'id_ID').format(date);
    } catch (e) {
      return "-";
    }
  }
}