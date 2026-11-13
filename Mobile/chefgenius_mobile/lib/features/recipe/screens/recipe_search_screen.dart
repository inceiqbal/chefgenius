import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart'; // IMPORT PROVIDER
import '../../../app/data/models/recipe_model.dart';
import '../widgets/recipe_card.dart';
import '../../../app/services/indonesian_recipe_service.dart'; 
import '../../../app/data/providers/language_provider.dart'; // IMPORT LANG PROVIDER
import '../../../app/data/providers/recipe_rating_provider.dart'; // IMPORT RATING PROVIDER

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
  
  static const String _placeholderImage = 'assets/images/Chef_Cei/chefceiberhasil.png';
  
  bool _isLoading = false;      
  bool _isLoadingMore = false;  
  bool _hasMore = true;         
  int _page = 0;                
  static const int _limit = 20; 
  
  Timer? _debounce;

  Set<String> _selectedFilters = {"all"}; // Default key
  
  // Map keyword tetap sama, cuma key-nya diganti inggris biar gampang mapping ke kamus
  final Map<String, List<String>> _categoryKeywords = {
    "all": [],
    "breakfast": ["egg", "telur", "omelet", "toast", "pancake", "waffle", "bubur", "breakfast"],
    "dessert": ["cake", "kue", "cookie", "pudding", "ice cream", "tart", "chocolate", "manis", "dessert"],
    "chicken": ["chicken", "ayam"],
    "beef": ["beef", "sapi", "meat", "steak"],
    "seafood": ["fish", "ikan", "shrimp", "udang", "seafood"],
  };
  
  // Rating filter categories
  final Map<String, String> _ratingFilters = {
    "rating_5": "⭐ 5",
    "rating_3_4": "⭐ 3-4",
    "rating_1_2": "⭐ 1-2",
  };
  
  Set<String> _selectedRatingFilters = {};
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

  // --- FUNGSI FILTER UI (UPDATED) ---
  void _showFilterBottomSheet() {
    final lang = context.read<LanguageProvider>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Temporary state for the bottom sheet
    Set<String> tempSelectedFilters = Set.from(_selectedFilters);
    Set<String> tempSelectedRatingFilters = Set.from(_selectedRatingFilters);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFE67E22), Color(0xFFD35400)]),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFFE67E22).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: const Icon(Icons.filter_list_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            lang.getText('filter_title'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setModalState(() {
                              tempSelectedFilters = {"all"};
                              tempSelectedRatingFilters = {};
                            });
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text("Reset"),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section: Kategori
                          _buildFilterSectionHeader(
                            Icons.category_rounded, 
                            'Kategori', 
                            const [Color(0xFF3498DB), Color(0xFF2980B9)],
                            isDarkMode,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _categoryKeywords.keys.map((categoryKey) {
                              final isSelected = tempSelectedFilters.contains(categoryKey);
                              final label = lang.getText('cat_$categoryKey');
                              
                              return _buildModernFilterChip(
                                label: label,
                                isSelected: isSelected,
                                selectedColor: Colors.orange,
                                isDarkMode: isDarkMode,
                                onSelected: (selected) {
                                  setModalState(() {
                                    if (categoryKey == "all") {
                                      if (selected) {
                                        tempSelectedFilters = {"all"};
                                      }
                                    } else {
                                      if (selected) {
                                        tempSelectedFilters.remove("all");
                                        tempSelectedFilters.add(categoryKey);
                                      } else {
                                        tempSelectedFilters.remove(categoryKey);
                                        if (tempSelectedFilters.isEmpty) {
                                          tempSelectedFilters.add("all");
                                        }
                                      }
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Section: Rating
                          _buildFilterSectionHeader(
                            Icons.star_rounded, 
                            'Rating', 
                            const [Color(0xFFF39C12), Color(0xFFE67E22)],
                            isDarkMode,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _ratingFilters.entries.map((entry) {
                              final isSelected = tempSelectedRatingFilters.contains(entry.key);
                              
                              return _buildModernFilterChip(
                                label: entry.value,
                                isSelected: isSelected,
                                selectedColor: Colors.amber,
                                isDarkMode: isDarkMode,
                                onSelected: (selected) {
                                  setModalState(() {
                                    if (selected) {
                                      tempSelectedRatingFilters.add(entry.key);
                                    } else {
                                      tempSelectedRatingFilters.remove(entry.key);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Apply Button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFE67E22), Color(0xFFD35400)]),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFFE67E22).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3)),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedFilters = tempSelectedFilters;
                              _selectedRatingFilters = tempSelectedRatingFilters;
                            });
                            Navigator.pop(context);
                            _performSearch(isRefresh: true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_rounded, size: 20),
                              SizedBox(width: 8),
                              Text("Terapkan Filter", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }
  
  Widget _buildFilterSectionHeader(IconData icon, String title, List<Color> gradient, bool isDarkMode) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
    );
  }
  
  Widget _buildModernFilterChip({
    required String label,
    required bool isSelected,
    required Color selectedColor,
    required bool isDarkMode,
    required Function(bool) onSelected,
  }) {
    return GestureDetector(
      onTap: () => onSelected(!isSelected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected 
              ? selectedColor.withOpacity(0.15)
              : (isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? selectedColor : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(Icons.check_rounded, size: 14, color: selectedColor),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? selectedColor : (isDarkMode ? Colors.white : Colors.black87),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
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

      String effectiveQuery = userQuery;
      
      const selectColumns = 
          'id, title, description, duration, servings, image_url, ingredients, main_ingredients, steps';

      List<dynamic> supabaseData;
      List<Recipe> indoRecipes = [];

      if (effectiveQuery.isNotEmpty) {
        // User typed something, search by title
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
        // User typed nothing, check filters
        if (!_selectedFilters.contains("all")) {
           List<String> allKeywords = [];
           for (var filter in _selectedFilters) {
              if (_categoryKeywords.containsKey(filter)) {
                allKeywords.addAll(_categoryKeywords[filter]!);
              }
           }
           
           if (allKeywords.isNotEmpty) {
              // Build OR query for Supabase
              final orQuery = allKeywords.map((k) => 'title.ilike.%$k%').join(',');
              
              supabaseData = await supabase
                 .from('recipes')
                 .select(selectColumns)
                 .or(orQuery)
                 .range(from, to);
                 
              // Optional: Fetch from IndoService using the first keyword
              if (_page == 0) {
                 try {
                    indoRecipes = await _indoService.searchRecipes(allKeywords.first);
                 } catch (e) {
                    // ignore
                 }
              }
           } else {
              // Fallback to all if keywords empty
              supabaseData = await supabase.from('recipes').select(selectColumns).range(from, to);
           }
        } else {
           // All selected, no query
           supabaseData = await supabase
              .from('recipes')
              .select(selectColumns)
              .range(from, to);
        }
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
          
          List<Recipe> combinedResults;
          if (isRefresh) {
             combinedResults = [...indoRecipes, ...supabaseResults];
          } else {
             combinedResults = supabaseResults;
          }
          
          // Apply rating filter if any rating filter is selected
          if (_selectedRatingFilters.isNotEmpty) {
            final ratingProvider = context.read<RecipeRatingProvider>();
            combinedResults = combinedResults.where((recipe) {
              final avgRating = ratingProvider.getAverageRating(recipe.id);
              
              for (final filter in _selectedRatingFilters) {
                if (filter == 'rating_5' && avgRating >= 4.5) return true;
                if (filter == 'rating_3_4' && avgRating >= 2.5 && avgRating < 4.5) return true;
                if (filter == 'rating_1_2' && avgRating > 0 && avgRating < 2.5) return true;
              }
              return false;
            }).toList();
          }
          
          if (isRefresh) {
            _searchResults = combinedResults;
          } else {
            _searchResults.addAll(combinedResults);
          }
          
          _page++; 
        });
      }
    } catch (e) {
      if (mounted) {
        // Pesan error biarin default dulu gpp, atau tambah di kamus 'search_error'
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
    // 1. WATCH LANGUAGE PROVIDER
    final lang = context.watch<LanguageProvider>();

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
            hintText: lang.getText('search_hint'), // "Cari resep..."
            hintStyle: TextStyle(color: appBarForegroundColor.withAlpha(178)),
            border: InputBorder.none,
          ),
        ),
        actions: [
          // --- TOMBOL FILTER ---
          IconButton(
            icon: Icon(
              Icons.filter_list, 
              color: _selectedFilters.contains("all") && _selectedFilters.length == 1 
                  ? appBarForegroundColor 
                  : Colors.orange
            ),
            tooltip: lang.getText('filter_title'), // "Filter Kategori"
            onPressed: _showFilterBottomSheet,
          ),
          // --------------------
          if (_searchController.text.isNotEmpty)
            IconButton(
              color: appBarForegroundColor,
              icon: const Icon(Icons.clear),
              // PERBAIKAN: Tambahin () sebelum kurung kurawal biar jadi fungsi
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
           if (!_selectedFilters.contains("all"))
             Container(
               width: double.infinity,
               color: Colors.orangeAccent.withOpacity(0.1),
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
               child: Row(
                 children: [
                   const Icon(Icons.check, size: 16, color: Colors.orangeAccent),
                   const SizedBox(width: 8),
                   // Terjemahkan nama filter di sini juga
                   Expanded(
                     child: Text(
                       lang.getText('filter_indicator')
                           .replaceAll('@filter', _selectedFilters.map((f) => lang.getText('cat_$f')).join(', ')), 
                       style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                       overflow: TextOverflow.ellipsis,
                     ),
                   ),
                   const SizedBox(width: 8),
                   InkWell(
                     onTap: () {
                       setState(() => _selectedFilters = {"all"});
                       _performSearch(isRefresh: true);
                     },
                     child: const Icon(Icons.close, size: 16, color: Colors.orangeAccent)
                   )
                 ],
               ),
             ),
             
           Expanded(
             child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _searchResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(lang.getText('search_empty'), style: const TextStyle(color: Colors.grey)), // "Resep tidak ditemukan."
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