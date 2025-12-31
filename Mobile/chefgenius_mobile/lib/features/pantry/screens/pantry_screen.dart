import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart'; 

import '../../../app/services/recommendation_service.dart';
import '../../../app/services/gemini_proxy_service.dart';
import '../../../app/config/routes.dart';
import '../../recipe/screens/cooking_history_screen.dart'; 
import '../../../app/widgets/custom_app_bar.dart';
import '../../../app/widgets/ai_loading_dialog.dart';
import '../../../app/data/providers/connectivity_provider.dart';
import '../../../app/data/providers/language_provider.dart'; 
import '../../../app/widgets/offline_banner.dart';
import '../widgets/ingredient_tile.dart';
import '../widgets/chef_status_bar.dart';
import '../widgets/quick_ingredient_chips.dart';
import '../widgets/pantry_input_section.dart';
import '../../../app/config/chef_cei_assets.dart'; 
import '../widgets/cei_showcase_wrapper.dart';
import '../widgets/pantry_empty_state.dart';
import '../widgets/pantry_search_button.dart';
import '../widgets/pantry_header.dart';
import '../widgets/level_up_dialog.dart';

class PantryScreen extends StatefulWidget {
  static const String showcaseKey = 'hasSeenPantryShowcase';
  final String email;
  final bool isVisible;
  const PantryScreen({super.key, required this.email, this.isVisible = true});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  final TextEditingController _ingredientController = TextEditingController();
  late Box<String> _pantryBox;
  bool _isLoading = true;
  bool _isAdding = false;
  bool _isSearching = false;
  final ImagePicker _picker = ImagePicker();
  
  int _userXp = 0;
  int _userLevel = 0;
  bool _isFirstLoad = true;
  
  static const int xpPerLevel = 300; 

  final supabase = Supabase.instance.client;

  // Key-key showcase
  final GlobalKey _levelingKey = GlobalKey();
  final GlobalKey _addIngredientKey = GlobalKey();
  final GlobalKey _searchNormalKey = GlobalKey(); 
  final GlobalKey _pantryListKey = GlobalKey();
  final GlobalKey _shoppingListKey = GlobalKey();
  final GlobalKey _historyKey = GlobalKey(); // Ini key terakhir
  final GlobalKey _repoKey = GlobalKey(); 
  final GlobalKey _helpKey = GlobalKey(); 

  bool _shouldAutoStartTour = false; 

  @override
  void initState() {
    super.initState();
    _initializeData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfFirstTime();
    });
    _loadUserStats();
  }

  // --- FUNGSI HELPER UNTUK TITLE SESUAI BAHASA ---
  String _getRankTitle(int level, LanguageProvider lang) {
    if (level < 2) return lang.getText('rank_newbie');      // Pastikan key ini ada di JSON bahasa
    if (level < 5) return lang.getText('rank_home_cook');   
    if (level < 10) return lang.getText('rank_chef');       
    if (level < 20) return lang.getText('rank_sous_chef');  
    return lang.getText('rank_master_chef');                
  }
  // -----------------------------------------------

  Future<void> _loadUserStats() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Ambil data lokal dulu
    int currentXp = prefs.getInt('user_xp') ?? 0;
    _updateLocalState(currentXp); 

    // 2. Cek ke Server Supabase
    final isOffline = Provider.of<ConnectivityProvider>(context, listen: false).isOffline;
    
    if (!isOffline) {
      try {
        final userId = supabase.auth.currentUser?.id;
        if (userId != null) {
          final data = await supabase
              .from('profiles')
              .select('xp')
              .eq('id', userId)
              .maybeSingle();

          if (data != null && data['xp'] != null) {
            int serverXp = data['xp'];
            if (serverXp != currentXp) {
              await prefs.setInt('user_xp', serverXp);
              _updateLocalState(serverXp); 
              debugPrint("XP Disinkronkan dari Server: $serverXp");
            }
          }
        }
      } catch (e) {
        debugPrint("Gagal sinkron XP dari server: $e");
      }
    }
  }

  void _updateLocalState(int xp) {
    if (mounted) {
      setState(() {
        int oldLevel = _userLevel;
        _userXp = xp;
        _userLevel = _userXp ~/ xpPerLevel; 
        
        // Cek Level Up (Hanya jika bukan load pertama)
        if (!_isFirstLoad && _userLevel > oldLevel) {
           WidgetsBinding.instance.addPostFrameCallback((_) {
             _showLevelUpDialog(_userLevel);
           });
        }
        _isFirstLoad = false;
      });
    }
  }

  void _showLevelUpDialog(int newLevel) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => LevelUpDialog(
        newLevel: newLevel,
        rankTitle: _getRankTitle(newLevel, lang),
        onContinue: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _initializeData() async {
    final userEmail = supabase.auth.currentUser?.email ?? 'guest';
    final boxName = 'pantry_$userEmail';
    if (!Hive.isBoxOpen(boxName)) {
      _pantryBox = await Hive.openBox<String>(boxName);
    } else {
      _pantryBox = Hive.box<String>(boxName);
    }
    if (mounted) {
      final isOffline = context.read<ConnectivityProvider>().isOffline;
      if (isOffline) {
        setState(() => _isLoading = false);
      } else {
        await _fetchInitialPantryItems();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUserStats();
  }

  Future<void> _checkIfFirstTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool hasSeenShowcase = prefs.getBool(PantryScreen.showcaseKey) ?? false;
      if (!hasSeenShowcase && mounted && widget.isVisible) {
        setState(() {
          _shouldAutoStartTour = true;
        });
      }
    } catch (e) {
      debugPrint("Gagal cek SharedPreferences: $e");
    }
  }

  @override
  void didUpdateWidget(PantryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isVisible && widget.isVisible) {
      _checkIfFirstTime();
      _loadUserStats(); // Refresh XP saat balik ke tab ini
    }
  }

  Future<void> _onShowcaseComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PantryScreen.showcaseKey, true);
  }

  Future<void> _resetAndStartTour(BuildContext ctx) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(PantryScreen.showcaseKey, false);
      await prefs.setBool('hasSeenAiShowcase', false);
      if (mounted) {
        ShowCaseWidget.of(ctx).startShowCase([
          _levelingKey, 
          _addIngredientKey, 
          _searchNormalKey,
          _pantryListKey, 
          _repoKey, 
          _helpKey, 
          _shoppingListKey, 
          _historyKey,
        ]);
      }
    } catch (e) {
      debugPrint("Gagal reset tur: $e");
    }
  }

  Future<void> _fetchInitialPantryItems() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final response = await supabase.from('pantry_items').select('id, ingredient_name').eq('user_id', userId);
      final Map<dynamic, String> hiveData = {};
      for (var item in response) {
        final int supabaseId = item['id'];
        final String name = item['ingredient_name'];
        hiveData[supabaseId] = name;
      }
      await _pantryBox.clear();
      await _pantryBox.putAll(hiveData);
    } catch (e) {
      if (mounted) {
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.getText('pantry_fetch_error')), backgroundColor: Theme.of(context).colorScheme.error));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- FITUR Cei Vision (via Proxy - API Key aman di server)
  Future<void> _scanIngredients() async {
    if (context.read<ConnectivityProvider>().isOffline) {
       final lang = Provider.of<LanguageProvider>(context, listen: false);
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.getText('pantry_offline_scan')), backgroundColor: Colors.orange));
       return;
    }
    // API Key sekarang tersimpan aman di server Edge Function
    // Tidak perlu cek API key lagi di client
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera, 
        imageQuality: 25, 
        maxWidth: 800,    
      );
      if (photo == null) return;
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AiLoadingDialog(
          text: "Cei sedang memindai...",
          imagePath: ChefCeiAssets.mataDewa, 
        ),
      );
      final bytes = await photo.readAsBytes();
      
      // Panggil Gemini via Proxy (API Key aman di server)
      final detectedItems = await GeminiProxyService().scanIngredients(imageBytes: bytes);
      
      int addedCount = 0;
      for (var name in detectedItems) {
        final trimmedName = name.trim();
        bool exists = _pantryBox.values.any((e) => e.toLowerCase() == trimmedName.toLowerCase());
        if (!exists && trimmedName.isNotEmpty) {
           await _addIngredient(trimmedName); 
           addedCount++;
        }
      }
      if (mounted) {
        Navigator.pop(context);
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        final msg = addedCount > 0 ? lang.getText('pantry_scan_success').replaceAll('@count', addedCount.toString()) : lang.getText('pantry_scan_empty');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: addedCount > 0 ? Colors.green : Colors.orange));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.getText('pantry_scan_fail').replaceAll('@error', e.toString())), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _addIngredient([String? specificItem]) async {
    // final lang = Provider.of<LanguageProvider>(context, listen: false);
    if (context.read<ConnectivityProvider>().isOffline) {
      final lang = Provider.of<LanguageProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.getText('pantry_offline_add')), backgroundColor: Colors.orange));
      return;
    }
    final ingredient = specificItem ?? _ingredientController.text.trim();
    if (ingredient.isEmpty || _pantryBox.values.contains(ingredient)) {
      if (specificItem == null && _pantryBox.values.contains(ingredient)) {
         final lang = Provider.of<LanguageProvider>(context, listen: false);
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.getText('pantry_item_exists').replaceAll('@item', ingredient))));
      }
      return;
    }
    setState(() => _isAdding = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User tidak login');
      final response = await supabase.from('pantry_items').insert({'user_id': userId, 'ingredient_name': ingredient}).select('id').single();
      final int newSupabaseId = response['id'];
      await _pantryBox.put(newSupabaseId, ingredient);
      if (specificItem == null) {
        _ingredientController.clear();
      }
      if (mounted && specificItem == null) FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) {
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.getText('pantry_add_fail').replaceAll('@item', ingredient)), backgroundColor: Theme.of(context).colorScheme.error));
      }
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  Future<void> _removeIngredient(dynamic hiveKey) async {
    if (context.read<ConnectivityProvider>().isOffline) {
      final lang = Provider.of<LanguageProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.getText('pantry_offline_delete')), backgroundColor: Colors.orange));
      return;
    }
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User tidak login');
      await supabase.from('pantry_items').delete().match({'id': hiveKey, 'user_id': userId});
      await _pantryBox.delete(hiveKey);
    } catch (e) {
      if (mounted) {
        final lang = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.getText('pantry_delete_fail')), backgroundColor: Theme.of(context).colorScheme.error));
      }
    }
  }

  Future<void> _clearAllPantry() async {
     final lang = Provider.of<LanguageProvider>(context, listen: false);
     if (context.read<ConnectivityProvider>().isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.getText('pantry_offline_delete_all'))));
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.getText('pantry_title')),
        content: const Text("Yakin mau kosongin kulkas? Nanti Cei masak apa dong? 🥺"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(lang.getText('cancel'))),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: Text(lang.getText('delete_all'))),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        await supabase.from('pantry_items').delete().eq('user_id', userId);
        await _pantryBox.clear();
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.getText('pantry_clear_fail').replaceAll('@error', e.toString()))));
      }
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _searchRecipes() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    if (context.read<ConnectivityProvider>().isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.getText('pantry_offline_search')), backgroundColor: Colors.orange));
      return;
    }
    if (_pantryBox.values.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.getText('pantry_empty_search'))));
      }
      return;
    }
    setState(() => _isSearching = true);
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AiLoadingDialog(text: lang.getText('search_recipe_loading'));
      },
    );
    try {
      final pantryItems = _pantryBox.values.toList();
      final recommendations = await RecommendationService().getRecommendations(pantryItems);
      if (mounted) Navigator.of(context).pop(); 
      if (mounted) {
        if (recommendations.isNotEmpty) {
          await Navigator.pushNamed(context, AppRoutes.recipeListRoute, arguments: recommendations).then((_) => _loadUserStats());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.getText('pantry_no_recipe'))));
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.getText('pantry_search_fail')), backgroundColor: Theme.of(context).colorScheme.error));
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  @override
  void dispose() {
    _ingredientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = context.watch<ConnectivityProvider>().isOffline;
    
    final lang = Provider.of<LanguageProvider>(context);

    // --- LOGIKA TITLE DI SINI BIAR REAKTIF ---
    // Panggil fungsi helper yang udah kita buat tadi
    String dynamicUserTitle = _getRankTitle(_userLevel, lang);
    // -----------------------------------------

    String rawIngredients = lang.getText('common_ingredients');
    List<String> commonIngredients;
    if (rawIngredients == 'common_ingredients' || !rawIngredients.contains(',')) {
       commonIngredients = ['Telur', 'Ayam', 'Nasi', 'Bawang', 'Cabai', 'Tahu', 'Tempe', 'Kecap', 'Susu', 'Roti'];
    } else {
       commonIngredients = rawIngredients.split(',').map((e) => e.trim()).toList();
    }

    return ShowCaseWidget(
      onStart: (index, key) {},
      onComplete: (index, key) {
        if (key == _historyKey) { 
          _onShowcaseComplete();
        }
      },
      onDismiss: (key) {
        _onShowcaseComplete();
      },
      blurValue: 1,
      builder: (innerContext) {
        if (_shouldAutoStartTour) {
          _shouldAutoStartTour = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
             _resetAndStartTour(innerContext);
          });
        }

        if (!widget.isVisible) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
             ShowCaseWidget.of(innerContext).dismiss();
          });
        }

        return Scaffold(
          appBar: CustomAppBar(
            title: lang.getText('pantry_title'),
            actions: [
              CeiShowcaseWrapper(
                showcaseKey: _helpKey,
                title: lang.getText('help_btn'),
                description: lang.getText('help_desc'),
                child: IconButton(
                  icon: const Icon(Icons.help_outline),
                  tooltip: lang.getText('help_btn'),
                  onPressed: () => _resetAndStartTour(innerContext),
                ),
              ),
          
          CeiShowcaseWrapper(
            showcaseKey: _shoppingListKey,
            title: lang.getText('shop_btn'),
            description: lang.getText('shop_desc'),
            child: IconButton(
              icon: const Icon(Icons.checklist_rtl_rounded), 
              tooltip: lang.getText('shop_btn'),
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.shoppingListRoute);
              },
            ),
          ),
          
          CeiShowcaseWrapper(
            showcaseKey: _historyKey,
            title: lang.getText('history_btn'),
            description: lang.getText('history_desc'),
            child: IconButton(
              icon: const Icon(Icons.history), 
              tooltip: lang.getText('history_btn'),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const CookingHistoryScreen()))
                    .then((_) => _loadUserStats());
              },
            ),
          ),

          CeiShowcaseWrapper(
            showcaseKey: _repoKey,
            title: lang.getText('fav_btn'),
            description: lang.getText('fav_desc'),
            child: IconButton(
              icon: const Icon(Icons.menu_book_rounded), // Icon Buku
              tooltip: 'Buku Resep',
              onPressed: () {
                if (isOffline) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Ups, lagi offline nih Bestie! 📶\nBuku resepnya gak bisa dibuka dulu ya. Coba cari sinyal yuk!',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 3),
                    ),
                  );
                } else {
                  Navigator.pushNamed(context, AppRoutes.recipeSearchRoute)
                      .then((_) => _loadUserStats());
                }
              },
            ),
          ),
        ],
      ),
      
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: OfflineBanner()),
              
              SliverToBoxAdapter(
                child: CeiShowcaseWrapper(
                  showcaseKey: _levelingKey,
                  title: lang.getText('level_title'),
                  description: lang.getText('level_desc'),
                  shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ChefStatusBar(
                    showcaseKey: GlobalKey(), 
                    userXp: _userXp,
                    userLevel: _userLevel,
                    userTitle: dynamicUserTitle, // <--- Pake variabel dinamis
                    xpPerLevel: xpPerLevel,
                  ),
                ),
              ),
              
              if (!isOffline)
                SliverToBoxAdapter(
                  child: QuickIngredientChips(
                    ingredients: commonIngredients,
                    isOffline: isOffline,
                    isAdding: _isAdding,
                    onAdd: _addIngredient,
                  ),
                ),
              
              SliverToBoxAdapter(
                child: CeiShowcaseWrapper(
                  showcaseKey: _addIngredientKey,
                  title: lang.getText('input_title'),
                  description: lang.getText('input_desc'),
                  shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: PantryInputSection(
                    showcaseKey: GlobalKey(), 
                    controller: _ingredientController,
                    isOffline: isOffline,
                    isAdding: _isAdding,
                    onScan: _scanIngredients,
                    onAdd: () => _addIngredient(),
                  ),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              
              SliverToBoxAdapter(
                child: CeiShowcaseWrapper(
                  showcaseKey: _searchNormalKey,
                  title: lang.getText('search_section_title'),
                  description: lang.getText('search_section_desc'),
                  shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  child: PantrySearchButton(
                    isSearching: _isSearching,
                    isOffline: isOffline,
                    isLoading: _isLoading,
                    onSearch: _searchRecipes,
                  ),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: PantryHeader(
                  isLoading: _isLoading,
                  hasItems: _pantryBox.isNotEmpty,
                  isOffline: isOffline,
                  onClearAll: _clearAllPantry,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 4)),
              
              SliverToBoxAdapter(
                child: CeiShowcaseWrapper(
                  showcaseKey: _pantryListKey,
                  title: lang.getText('pantry_list_title'),
                  description: lang.getText('pantry_list_desc'),
                  shapeBorder: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ValueListenableBuilder(
                          valueListenable: _pantryBox.listenable(),
                          builder: (context, Box<String> box, _) {
                            if (box.isEmpty) {
                              return PantryEmptyState(
                                title: lang.getText('pantry_empty_title'),
                                subtitle: lang.getText('pantry_empty_subtitle'),
                              );
                            }
                            final keys = box.keys.toList();
                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: box.length,
                              itemBuilder: (context, index) {
                                final hiveKey = keys[index];
                                final ingredient = box.get(hiveKey)!;
                                return IngredientTile(
                                  name: ingredient,
                                  onDelete: isOffline ? () => _removeIngredient(hiveKey) : () => _removeIngredient(hiveKey),
                                );
                              },
                            );
                          },
                        ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)), // Extra padding for bottom
            ],
          ),
        ],
      ),
    );
      },
    );
  }
}
