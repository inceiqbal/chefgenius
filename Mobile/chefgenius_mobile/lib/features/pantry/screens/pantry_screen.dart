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
// 🔥 DISABLED IMPORT for RAGAS evaluation
// import '../../../app/widgets/custom_app_bar.dart';
import '../../../app/widgets/ai_loading_dialog.dart';
import '../../../app/widgets/modern_alert_dialog.dart';
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
// 🔥 DISABLED IMPORT for RAGAS evaluation
// import '../widgets/level_up_dialog.dart';

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
  final TextEditingController _quantityController = TextEditingController(); // NEW: Quantity input
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

  // 🔥 DISABLED FIELDS for RAGAS evaluation
  // bool _shouldAutoStartTour = false; 
  // bool _isShowingLevelUp = false; // Flag untuk tracking dialog level up

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
    // 🔥 DISABLE LEVEL-UP NOTIFICATION DIALOG UNTUK EVALUASI RAGAS
    // _isShowingLevelUp = true; // Set flag sebelum show dialog
    // final lang = Provider.of<LanguageProvider>(context, listen: false);
    // showDialog(
    //   context: context,
    //   barrierDismissible: false,
    //   builder: (context) => LevelUpDialog(
    //     newLevel: newLevel,
    //     rankTitle: _getRankTitle(newLevel, lang),
    //     onContinue: () {
    //       Navigator.pop(context);
    //       _isShowingLevelUp = false; // Reset flag setelah dialog ditutup
    //       // Jalankan showcase yang tertunda (jika ada)
    //       if (_shouldAutoStartTour && mounted) {
    //         _shouldAutoStartTour = false;
    //         WidgetsBinding.instance.addPostFrameCallback((_) {
    //           if (mounted) {
    //             // Perlu akses ShowCaseWidget context, akan ditangani di build
    //             setState(() {
    //               _shouldAutoStartTour = true; // Trigger rebuild untuk jalankan tour
    //             });
    //           }
    //         });
    //       }
    //     },
    //   ),
    // );
    debugPrint('[EVAL MODE] Level up to $newLevel suppressed for RAGAS evaluation');
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
      // 🔥 DISABLE SHOWCASE FOR RAGAS EVALUATION
      // final bool hasSeenShowcase = prefs.getBool(PantryScreen.showcaseKey) ?? false;
      // if (!hasSeenShowcase && mounted && widget.isVisible) {
      //   setState(() {
      //     _shouldAutoStartTour = true;
      //   });
      // }
      
      // Mark showcase as seen to prevent it from triggering
      await prefs.setBool(PantryScreen.showcaseKey, true);
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
      // NEW: Fetch quantity column too
      final response = await supabase.from('pantry_items').select('id, ingredient_name, quantity').eq('user_id', userId);
      final Map<dynamic, String> hiveData = {};
      for (var item in response) {
        final int supabaseId = item['id'];
        final String name = item['ingredient_name'];
        final String quantity = item['quantity'] ?? ''; // NEW: Get quantity
        // Store as JSON: "name|quantity" for backward compatibility
        hiveData[supabaseId] = quantity.isEmpty ? name : '$name|$quantity';
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
      // NEW: detectedItems now returns List<Map<String, String>>
      for (var item in detectedItems) {
        final name = item['name']!.trim();
        final quantity = item['quantity']!.trim();
        
        // Check if ingredient already exists (by name only)
        bool exists = _pantryBox.values.any((pantryItem) {
          final parts = pantryItem.split('|');
          return parts[0].toLowerCase() == name.toLowerCase();
        });
        
        if (!exists && name.isNotEmpty) {
           await _addIngredient(name, quantity.isEmpty ? null : quantity); 
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

  Future<void> _addIngredient([String? specificItem, String? specificQuantity]) async {
    // final lang = Provider.of<LanguageProvider>(context, listen: false);
    if (context.read<ConnectivityProvider>().isOffline) {
      final lang = Provider.of<LanguageProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.getText('pantry_offline_add')), backgroundColor: Colors.orange));
      return;
    }
    final ingredient = specificItem ?? _ingredientController.text.trim();
    final quantity = specificQuantity ?? _quantityController.text.trim(); // NEW: Get quantity
    
    // Check if ingredient name already exists (ignore quantity for duplicate check)
    bool exists = _pantryBox.values.any((item) {
      final parts = item.split('|');
      return parts[0] == ingredient;
    });
    
    if (ingredient.isEmpty || exists) {
      if (specificItem == null && exists) {
         final lang = Provider.of<LanguageProvider>(context, listen: false);
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.getText('pantry_item_exists').replaceAll('@item', ingredient))));
      }
      return;
    }
    setState(() => _isAdding = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User tidak login');
      // NEW: Insert with quantity
      final response = await supabase.from('pantry_items').insert({
        'user_id': userId, 
        'ingredient_name': ingredient,
        'quantity': quantity, // NEW: Include quantity
      }).select('id').single();
      final int newSupabaseId = response['id'];
      // Store as "name|quantity"
      await _pantryBox.put(newSupabaseId, quantity.isEmpty ? ingredient : '$ingredient|$quantity');
      if (specificItem == null) {
        _ingredientController.clear();
        _quantityController.clear(); // NEW: Clear quantity too
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

  // NEW: Edit ingredient
  Future<void> _editIngredient(dynamic hiveKey, String currentValue) async {
    if (context.read<ConnectivityProvider>().isOffline) {
      final lang = Provider.of<LanguageProvider>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.getText('pantry_offline_add')), backgroundColor: Colors.orange));
      return;
    }

    // Parse current value
    final parts = currentValue.split('|');
    final currentName = parts[0];
    final currentQuantity = parts.length > 1 ? parts[1] : '';

    // Show edit dialog
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _EditIngredientDialog(
        initialName: currentName,
        initialQuantity: currentQuantity,
      ),
    );

    if (result == null) return; // User cancelled

    final newName = result['name']!;
    final newQuantity = result['quantity']!;

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User tidak login');

      // Update in Supabase
      await supabase.from('pantry_items').update({
        'ingredient_name': newName,
        'quantity': newQuantity,
      }).match({'id': hiveKey, 'user_id': userId});

      // Update in Hive
      final combined = newQuantity.isEmpty ? newName : '$newName|$newQuantity';
      await _pantryBox.put(hiveKey, combined);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bahan berhasil diupdate')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal update bahan: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    }
  }

  Future<void> _clearAllPantry() async {
     final lang = Provider.of<LanguageProvider>(context, listen: false);
     if (context.read<ConnectivityProvider>().isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.getText('pantry_offline_delete_all'))));
      return;
    }
    final confirm = await ModernAlertDialog.showConfirmation(
      context: context,
      title: lang.getText('pantry_title'),
      message: "Yakin mau kosongin kulkas? Nanti Cei masak apa dong? 🥺",
      confirmText: lang.getText('delete_all'),
      cancelText: lang.getText('cancel'),
      icon: Icons.cleaning_services_rounded,
      isDestructive: true,
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

  Widget _buildModernActionButton({
    required IconData icon,
    required Color color,
    required bool isDarkMode,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton(
        onPressed: onPressed,
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(isDarkMode ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }

  @override
  void dispose() {
    _ingredientController.dispose();
    _quantityController.dispose(); // NEW: Dispose quantity controller
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
        // 🔥 DISABLE SHOWCASE FOR RAGAS EVALUATION
        // Hanya jalankan showcase jika tidak sedang ada dialog level up
        // if (_shouldAutoStartTour && !_isShowingLevelUp) {
        //   _shouldAutoStartTour = false;
        //   WidgetsBinding.instance.addPostFrameCallback((_) {
        //      _resetAndStartTour(innerContext);
        //   });
        // }

        if (!widget.isVisible) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
             ShowCaseWidget.of(innerContext).dismiss();
          });
        }

        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        
        return Scaffold(
          backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFFAFAFA),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: isDarkMode ? const Color(0xFF1A1A2E) : const Color(0xFFFFF8F0),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFE67E22), Color(0xFFD35400)]),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFE67E22).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: const Icon(Icons.kitchen_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  lang.getText('pantry_title'),
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            actions: [
              CeiShowcaseWrapper(
                showcaseKey: _helpKey,
                title: lang.getText('help_btn'),
                description: lang.getText('help_desc'),
                child: _buildModernActionButton(
                  icon: Icons.help_outline_rounded,
                  color: Colors.blue,
                  isDarkMode: isDarkMode,
                  onPressed: () => _resetAndStartTour(innerContext),
                ),
              ),
          
              CeiShowcaseWrapper(
                showcaseKey: _shoppingListKey,
                title: lang.getText('shop_btn'),
                description: lang.getText('shop_desc'),
                child: _buildModernActionButton(
                  icon: Icons.checklist_rtl_rounded,
                  color: Colors.green,
                  isDarkMode: isDarkMode,
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.shoppingListRoute),
                ),
              ),
          
              CeiShowcaseWrapper(
                showcaseKey: _historyKey,
                title: lang.getText('history_btn'),
                description: lang.getText('history_desc'),
                child: _buildModernActionButton(
                  icon: Icons.history_rounded,
                  color: Colors.purple,
                  isDarkMode: isDarkMode,
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
                child: _buildModernActionButton(
                  icon: Icons.menu_book_rounded,
                  color: Colors.orange,
                  isDarkMode: isDarkMode,
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
              const SizedBox(width: 8),
            ],
          ),
      
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: Theme.of(context).brightness == Brightness.dark
                ? [const Color(0xFF1A1A2E), const Color(0xFF16213E), const Color(0xFF0F0F1A)]
                : [const Color(0xFFFFF8F0), const Color(0xFFFFF5EB), const Color(0xFFFFFFFF)],
          ),
        ),
        child: Stack(
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
                    quantityController: _quantityController, // NEW: Pass quantity controller
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
                                  onEdit: () => _editIngredient(hiveKey, ingredient), // NEW: Edit callback
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
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            // Softer warm orange gradient
            colors: [Color(0xFFE67E22), Color(0xFFD35400)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE67E22).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.chatbotRoute);
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.chat_rounded, color: Colors.white),
          label: Text(
            lang.getText('chatbot_fab'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
      },
    );
  }
}

// NEW: Edit Ingredient Dialog
class _EditIngredientDialog extends StatefulWidget {
  final String initialName;
  final String initialQuantity;

  const _EditIngredientDialog({
    required this.initialName,
    required this.initialQuantity,
  });

  @override
  State<_EditIngredientDialog> createState() => _EditIngredientDialogState();
}

class _EditIngredientDialogState extends State<_EditIngredientDialog> {
  late TextEditingController _nameController;
  late TextEditingController _quantityController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _quantityController = TextEditingController(text: widget.initialQuantity);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // Header with gradient
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE67E22), Color(0xFFD35400)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.edit_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      Provider.of<LanguageProvider>(context, listen: false).getText('edit_ingredient_title'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Name input
                  TextField(
                    controller: _nameController,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      labelText: Provider.of<LanguageProvider>(context, listen: false).getText('ingredient_name_label'),
                      labelStyle: TextStyle(color: Colors.grey.shade500),
                      prefixIcon: Icon(Icons.restaurant_rounded, color: Colors.orange.shade400, size: 20),
                      filled: true,
                      fillColor: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Colors.orange, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Quantity input
                  TextField(
                    controller: _quantityController,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Jumlah (opsional)',
                      hintText: '100 gram, 2 butir, dll',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      labelStyle: TextStyle(color: Colors.grey.shade500),
                      prefixIcon: Icon(Icons.scale_rounded, color: Colors.blue.shade400, size: 20),
                      filled: true,
                      fillColor: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Colors.blue, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
            
            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Text(
                        'Batal',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE67E22), Color(0xFFD35400)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE67E22).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          final name = _nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Nama bahan tidak boleh kosong'),
                                backgroundColor: Colors.red.shade400,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                            return;
                          }
                          Navigator.pop(context, {
                            'name': name,
                            'quantity': _quantityController.text.trim(),
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Simpan',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}
