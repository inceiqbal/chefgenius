import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/data/models/recipe_model.dart';
import '../widgets/recipe_card.dart';
import '../../../app/services/indonesian_recipe_service.dart'; 

class RecipeSearchScreen extends StatefulWidget {
  const RecipeSearchScreen({super.key});
  @override
  State<RecipeSearchScreen> createState() => _RecipeSearchScreenState();
}

class _RecipeSearchScreenState extends State<RecipeSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final supabase = Supabase.instance.client;
  final IndonesianRecipeService _indoService = IndonesianRecipeService(); 

  List<Recipe> _searchResults = [];
  List<int> _favoriteRecipeIds = [];
  
  static const String _placeholderImage = '[https://images.unsplash.com/photo-1546069901-ba9599a7e63c?q=80&w=1000&auto=format&fit=crop](https://images.unsplash.com/photo-1546069901-ba9599a7e63c?q=80&w=1000&auto=format&fit=crop)';
  
  bool _isLoading = false;      
  bool _isLoadingMore = false;  
  bool _hasMore = true;         
  int _page = 0;                
  static const int _limit = 20; 
  
  Timer? _debounce;

  // --- FITUR FILTER BARU ---
  String _selectedFilter = "Semua"; // Default
  final Map<String, List<String>> _categoryKeywords = {
    "Semua": [],
    "Sarapan": ["egg", "telur", "omelet", "toast", "pancake", "waffle", "bubur", "breakfast"],
    "Dessert": ["cake", "kue", "cookie", "pudding", "ice cream", "tart", "chocolate", "manis", "dessert"],
    "Ayam": ["chicken", "ayam"],
    "Daging": ["beef", "sapi", "meat", "steak"],
    "Seafood": ["fish", "ikan", "shrimp", "udang", "seafood"],
  };
  // -------------------------

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);

    _fetchFavoriteIds();
    _performSearch(isRefresh: true);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore && !_isLoading) {
        _loadMore();
      }
    }
  }

  Future<void> _fetchFavoriteIds() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final List<dynamic> favorites = await supabase
          .from('favorite_recipes')
          .select('recipe_id')
          .eq('user_id', userId);

      if (mounted) {
        setState(() {
          _favoriteRecipeIds =
              favorites.map((f) => f['recipe_id'] as int).toList();
        });
      }
    } catch (e) {
      // Silent error
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(isRefresh: true);
    });
  }

  // --- FUNGSI FILTER UI ---
  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Filter Kategori", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categoryKeywords.keys.map((category) {
                  final isSelected = _selectedFilter == category;
                  return ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedFilter = category);
                        Navigator.pop(context);
                        _performSearch(isRefresh: true); // Refresh data dengan filter baru
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
  // -----------------------

  Future<void> _performSearch({bool isRefresh = false}) async {
    if (!mounted) return;

    setState(() {
      if (isRefresh) {
        _isLoading = true;
        _page = 0;       
        _hasMore = true; 
        _searchResults.clear(); 
      }
    });

    try {
      final userQuery = _searchController.text.trim();
      final from = _page * _limit;
      final to = from + _limit - 1;

      // --- LOGIKA DETEKTIF KATA KUNCI ---
      // Gabungin query user + kata kunci kategori
      String effectiveQuery = userQuery;
      
      // Kalau ada filter kategori aktif (selain 'Semua')
      if (_selectedFilter != "Semua") {
        // Kita ambil salah satu keyword utamanya aja buat 'mewakili' pencarian
        // (Keterbatasan 'ilike' cuma bisa 1 pattern string sederhana)
        final keywords = _categoryKeywords[_selectedFilter]!;
        if (keywords.isNotEmpty) {
           // Kalau user gak ngetik apa2, kita pake keyword kategori
           if (effectiveQuery.isEmpty) {
             effectiveQuery = keywords.first; // Misal: cari 'cake' kalo pilih Dessert
           } 
           // Kalau user ngetik, kita biarin aja (filter SQL yang lebih canggih butuh setup TextSearch di Supabase)
           // Untuk sekarang, kita pake pendekatan "User Query" dulu.
           // *Catatan: Idealnya pake Full Text Search, tapi ini workaround 'Lite'.
        }
      }
      // ----------------------------------

      const selectColumns = 
          'id, title, description, duration, servings, image_url, ingredients, main_ingredients, steps';

      List<dynamic> supabaseData;
      List<Recipe> indoRecipes = [];

      if (effectiveQuery.isNotEmpty) {
        // Pencarian Supabase dengan Filter
        // Kita pake logic OR sederhana untuk keyword kategori kalau Supabase mendukung TextSearch
        // Tapi karena pake 'ilike', kita cari berdasarkan effectiveQuery yang udah diset.
        
        supabaseData = await supabase
            .from('recipes')
            .select(selectColumns)
            .ilike('title', '%$effectiveQuery%')
            .range(from, to);
        
        if (_page == 0) {
          try {
             indoRecipes = await _indoService.searchRecipes(effectiveQuery);
          } catch (e) {
             debugPrint("API Indo lagi tidur: $e"); 
          }
        }

      } else {
        supabaseData = await supabase
            .from('recipes')
            .select(selectColumns)
            .range(from, to);
      }
      
      List<Recipe> supabaseResults = supabaseData.map((json) {
        final recipe = Recipe.fromJson(json, isGeneratedByAi: false);
        
        final String dbImageUrl = json['image_url'] ?? '';
        if (dbImageUrl.isNotEmpty) {
          if (dbImageUrl.contains('supabase.co')) {
             final String filename = dbImageUrl.split('/').last;
             recipe.imageUrl = supabase.storage
                .from('recipe-images')
                .getPublicUrl('Food Images/$filename');
          } else if (dbImageUrl.startsWith('http')) {
             recipe.imageUrl = dbImageUrl; 
          } else {
             final String filename = dbImageUrl.split('/').last; 
             recipe.imageUrl = supabase.storage
                .from('recipe-images')
                .getPublicUrl('Food Images/$filename');
          }
        } else {
          recipe.imageUrl = _placeholderImage;
        }
        
        recipe.isFavorite = _favoriteRecipeIds.contains(recipe.id);
        return recipe;
      }).toList();

      if (mounted) {
        setState(() {
          if (supabaseResults.length < _limit) {
            _hasMore = false;
          }
          
          if (isRefresh) {
             _searchResults = [...indoRecipes, ...supabaseResults];
          } else {
             _searchResults.addAll(supabaseResults);
          }
          
          _page++; 
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memuat resep: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    await _performSearch(isRefresh: false);
    if (mounted) setState(() => _isLoadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    final appBarForegroundColor = Theme.of(context).appBarTheme.foregroundColor ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: false, 
          style: TextStyle(color: appBarForegroundColor),
          decoration: InputDecoration(
            hintText: 'Cari resep kesukaanmu di sini🤗...', 
            hintStyle: TextStyle(color: appBarForegroundColor.withAlpha(178)),
            border: InputBorder.none,
          ),
        ),
        actions: [
          // --- TOMBOL FILTER ---
          IconButton(
            icon: Icon(
              Icons.filter_list, 
              color: _selectedFilter == "Semua" ? appBarForegroundColor : Colors.blueAccent
            ),
            tooltip: "Filter Kategori",
            onPressed: _showFilterBottomSheet,
          ),
          // --------------------
          if (_searchController.text.isNotEmpty)
            IconButton(
              color: appBarForegroundColor,
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                _performSearch(isRefresh: true); 
              },
            ),
        ],
      ),
      body: Column(
        children: [
           // Indikator Filter Aktif
           if (_selectedFilter != "Semua")
             Container(
               width: double.infinity,
               color: Colors.blueAccent.withOpacity(0.1),
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
               child: Row(
                 children: [
                   const Icon(Icons.check, size: 16, color: Colors.blueAccent),
                   const SizedBox(width: 8),
                   Text("Kategori: $_selectedFilter", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                   const Spacer(),
                   InkWell(
                     onTap: () {
                       setState(() => _selectedFilter = "Semua");
                       _performSearch(isRefresh: true);
                     },
                     child: const Icon(Icons.close, size: 16, color: Colors.blueAccent)
                   )
                 ],
               ),
             ),
             
           Expanded(
             child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _searchResults.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('Resep tidak ditemukan.', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController, 
                      padding: const EdgeInsets.all(8.0),
                      itemCount: _searchResults.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _searchResults.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        _searchResults[index].score = 0;
                        return RecipeCard(recipe: _searchResults[index]);
                      },
                    ),
           ),
        ],
      ),
    );
  }
}