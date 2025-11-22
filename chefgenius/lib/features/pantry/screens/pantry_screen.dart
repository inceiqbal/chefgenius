import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:google_generative_ai/google_generative_ai.dart'; 

import '../../../app/services/recommendation_service.dart';
import '../../../app/config/routes.dart';
import '../../recipe/screens/cooking_history_screen.dart'; 
import '../../../app/widgets/custom_app_bar.dart';
import '../../../app/widgets/ai_loading_dialog.dart';
import '../../../app/data/providers/connectivity_provider.dart';
import '../../../app/widgets/offline_banner.dart';
import '../widgets/ingredient_tile.dart';
import '../../../app/config/gemini_config.dart';

import '../widgets/chef_status_bar.dart';
import '../widgets/quick_ingredient_chips.dart';
import '../widgets/pantry_input_section.dart';
import '../widgets/repo_floating_button.dart';

import '../../../app/config/chef_cei_assets.dart'; // ASET CHEF CEI

class PantryScreenWithShowcase extends StatelessWidget {
  final String email;
  const PantryScreenWithShowcase({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      onStart: (index, key) {},
      onComplete: (index, key) {
        if (key == _PantryScreenState._generateAIKey) {
          _PantryScreenState._onShowcaseComplete();
        }
      },
      onDismiss: (key) {
        _PantryScreenState._onShowcaseComplete();
      },
      blurValue: 1,
      builder: (context) => PantryScreen(email: email),
    );
  }
}

class PantryScreen extends StatefulWidget {
  static const String showcaseKey = 'hasSeenPantryShowcase';
  final String email;
  const PantryScreen({super.key, required this.email});

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
  String _userTitle = "Pemula";
  static const int xpPerLevel = 300; 

  final List<String> _commonIngredients = [
    'Telur', 'Ayam', 'Nasi', 'Bawang', 'Cabai', 
    'Tahu', 'Tempe', 'Kecap', 'Susu', 'Roti'
  ];

  final supabase = Supabase.instance.client;

  static final GlobalKey _levelingKey = GlobalKey();
  static final GlobalKey _addIngredientKey = GlobalKey();
  static final GlobalKey _searchNormalKey = GlobalKey(); 
  static final GlobalKey _pantryListKey = GlobalKey();
  static final GlobalKey _shoppingListKey = GlobalKey();
  static final GlobalKey _historyKey = GlobalKey(); 
  static final GlobalKey _repoKey = GlobalKey(); 
  static final GlobalKey _helpKey = GlobalKey(); 
  static final GlobalKey _generateAIKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initializeData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfFirstTime();
    });
    _loadUserStats();
  }

  // --- HELPER BARU: CUSTOM SHOWCASE DENGAN GAMBAR CHEF CEI ---
  // PERBAIKAN: height & width dipindah ke Container
  Widget _buildCeiShowcase({
    required GlobalKey key,
    required String title,
    required String description,
    required Widget child,
    ShapeBorder? shapeBorder, 
  }) {
    return Showcase.withWidget(
      key: key,
      // HAPUS height & width DARI SINI (Ini penyebab errornya)
      targetShapeBorder: shapeBorder ?? const CircleBorder(),
      container: Container( // PINDAHIN UKURANNYA KE SINI
        height: 230, 
        width: 260,  
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // GAMBAR CHEF CEI GUIDE
            Image.asset(
              'assets/images/Chef_Cei/chefceiguide.png', 
              height: 100, // Ukuran gambar kartun
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.orange, 
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
            ),
          ],
        ),
      ),
      child: child,
    );
  }
  // ------------------------------------------------------------

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

  Future<void> _loadUserStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); 
    if (mounted) {
      setState(() {
        _userXp = prefs.getInt('user_xp') ?? 0;
        _userLevel = _userXp ~/ xpPerLevel; 
        if (_userLevel < 2) { _userTitle = "Anak Kos"; } 
        else if (_userLevel < 5) { _userTitle = "Koki Rumahan"; } 
        else if (_userLevel < 10) { _userTitle = "Chef Handal"; } 
        else if (_userLevel < 20) { _userTitle = "Sous Chef"; } 
        else { _userTitle = "Master Chef"; }
      });
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
      if (!hasSeenShowcase && mounted) {
        ShowCaseWidget.of(context).startShowCase([
          _levelingKey, _addIngredientKey, _searchNormalKey,
          _pantryListKey, _repoKey, 
          _helpKey, _shoppingListKey, _historyKey,
          _generateAIKey,
        ]);
      }
    } catch (e) {
      debugPrint("Gagal cek SharedPreferences: $e");
    }
  }

  static Future<void> _onShowcaseComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PantryScreen.showcaseKey, true);
  }

  Future<void> _resetAndStartTour() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(PantryScreen.showcaseKey, false);
      await prefs.setBool('hasSeenAiShowcase', false);
      if (mounted) {
        ShowCaseWidget.of(context).startShowCase([
          _levelingKey, _addIngredientKey, _searchNormalKey,
          _pantryListKey, _repoKey, 
          _helpKey, _shoppingListKey, _historyKey,
          _generateAIKey,
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal muat pantry dari server. Cek internet lo, bro.'), backgroundColor: Theme.of(context).colorScheme.error));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- FITUR Cei Vision
  Future<void> _scanIngredients() async {
    if (context.read<ConnectivityProvider>().isOffline) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fitur Cei Vision butuh internet, Sob!"), backgroundColor: Colors.orange));
       return;
    }
    // API Key Rotasi
    final apiKey = GeminiConfig.apiKey;
    if (apiKey.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("API Key belum diset! Cek gemini_config.dart"), backgroundColor: Colors.red));
       return;
    }
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
        // PAKE VISUAL Cei Vision
        builder: (ctx) => const AiLoadingDialog(
          text: "Cei sedang memindai...",
          imagePath: ChefCeiAssets.mataDewa, 
        ),
      );
      final bytes = await photo.readAsBytes();
      final model = GenerativeModel(model: 'gemini-2.5-flash-preview-09-2025', apiKey: apiKey);
      final prompt = """
      Identifikasi bahan makanan utama dalam gambar.
      Aturan:
      1. Kemasan -> Nama jenis produk (misal: 'Kecap', 'Susu').
      2. JANGAN sebut komposisi.
      3. Output: JSON Array String Bahasa Indonesia.
      Contoh: ["Telur", "Tahu"].
      NO TEXT LAIN.
      """;
      final content = [Content.multi([TextPart(prompt), DataPart('image/jpeg', bytes)])];
      final response = await model.generateContent(content);
      final text = response.text ?? "[]";
      final jsonString = text.replaceAll('```json\n', '').replaceAll('\n```', '').trim();
      final List<dynamic> detectedItems = jsonDecode(jsonString);
      int addedCount = 0;
      for (var item in detectedItems) {
        String name = item.toString().trim();
        bool exists = _pantryBox.values.any((e) => e.toLowerCase() == name.toLowerCase());
        if (!exists && name.isNotEmpty) {
           await _addIngredient(name); 
           addedCount++;
        }
      }
      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(addedCount > 0 ? "Cei menemukan $addedCount bahan!" : "Tidak ada bahan baru yang ditemukan."), backgroundColor: addedCount > 0 ? Colors.green : Colors.orange));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal memindai: $e"), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _addIngredient([String? specificItem]) async {
    if (context.read<ConnectivityProvider>().isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kamu lagi offline! Gak bisa nambah bahan, Sob.'), backgroundColor: Colors.orange));
      return;
    }
    final ingredient = specificItem ?? _ingredientController.text.trim();
    if (ingredient.isEmpty || _pantryBox.values.contains(ingredient)) {
      if (specificItem == null && _pantryBox.values.contains(ingredient)) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$ingredient udah ada di pantry!')));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal nambah $ingredient. Cek internet.'), backgroundColor: Theme.of(context).colorScheme.error));
      }
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  Future<void> _removeIngredient(dynamic hiveKey) async {
    if (context.read<ConnectivityProvider>().isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kamu lagi offline! Gak bisa hapus bahan, Sob.'), backgroundColor: Colors.orange));
      return;
    }
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User tidak login');
      await supabase.from('pantry_items').delete().match({'id': hiveKey, 'user_id': userId});
      await _pantryBox.delete(hiveKey);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal hapus bahan. Coba cek internet atau coba lagi.'), backgroundColor: Theme.of(context).colorScheme.error));
      }
    }
  }

  Future<void> _clearAllPantry() async {
     if (context.read<ConnectivityProvider>().isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offline mode: Gak bisa hapus semua.')));
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Kosongkan Pantry?"),
        content: const Text("Yakin mau hapus SEMUA bahan? Gak bisa di-undo lho."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text("Hapus Semua")),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengosongkan pantry: $e')));
      }
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _searchRecipes() async {
    if (context.read<ConnectivityProvider>().isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fitur "Cari Resep" butuh internet, Sob!'), backgroundColor: Colors.orange));
      return;
    }
    if (_pantryBox.values.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tambahkan bahan dulu untuk mencari resep!')));
      }
      return;
    }
    setState(() => _isSearching = true);
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return const AiLoadingDialog(text: 'Mencari resep terbaik...');
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak ada resep yang cocok. Coba tambah bahan lain!')));
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal nyari resep. Coba cek internet lo. (${e.toString()})'), backgroundColor: Theme.of(context).colorScheme.error));
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
    if (mounted) {
      ShowCaseWidget.of(context).dismiss();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserEmail = supabase.auth.currentUser?.email ?? widget.email;
    final isOffline = context.watch<ConnectivityProvider>().isOffline;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Pantry Saya',
        actions: [
          // TOMBOL BANTUAN
          _buildCeiShowcase(
            key: _helpKey,
            title: 'Bantuan',
            description: 'Bingung? Klik ini buat ulangi tur petunjuk bareng Cei!',
            child: IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'Ulangi Tur',
              onPressed: _resetAndStartTour,
            ),
          ),
          
          // TOMBOL SHOPPING LIST
          _buildCeiShowcase(
            key: _shoppingListKey,
            title: 'Keranjang Belanja',
            description: 'Cek barang yang mau dibeli di sini.',
            child: IconButton(
              icon: const Icon(Icons.shopping_cart),
              tooltip: 'Keranjang Belanja',
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.shoppingListRoute);
              },
            ),
          ),
          
          // TOMBOL HISTORY
          _buildCeiShowcase(
            key: _historyKey,
            title: 'Jejak Kuliner',
            description: 'Lupa tadi masak apa? Cek riwayat masakan lo di sini.',
            child: IconButton(
              icon: const Icon(Icons.history), 
              tooltip: 'Riwayat Masak',
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const CookingHistoryScreen()));
              },
            ),
          ),
          
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profil Saya',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.profileRoute, arguments: currentUserEmail),
          ),
        ],
      ),
      
      body: Stack(
        children: [
          Column(
            children: [
              const OfflineBanner(),
              
              // STATUS BAR (LEVEL) - BENTUKNYA KOTAK (ROUNDED)
              _buildCeiShowcase(
                key: _levelingKey,
                title: 'Level Memasak',
                description: 'Makin sering masak, makin tinggi level lo!',
                shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ChefStatusBar(
                  showcaseKey: GlobalKey(), // Key udah dipake di wrapper showcase
                  userXp: _userXp,
                  userLevel: _userLevel,
                  userTitle: _userTitle,
                  xpPerLevel: xpPerLevel,
                ),
              ),
              
              if (!isOffline)
                QuickIngredientChips(
                  ingredients: _commonIngredients,
                  isOffline: isOffline,
                  isAdding: _isAdding,
                  onAdd: _addIngredient,
                ),
              
              // INPUT SECTION
              _buildCeiShowcase(
                key: _addIngredientKey,
                title: 'Input Bahan',
                description: 'Ketik manual atau pake "Cei Vision" (Kamera) buat scan bahan otomatis!',
                shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: PantryInputSection(
                  showcaseKey: GlobalKey(), // Key dummy karena wrapper udah handle showcase
                  controller: _ingredientController,
                  isOffline: isOffline,
                  isAdding: _isAdding,
                  onScan: _scanIngredients,
                  onAdd: () => _addIngredient(),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // TOMBOL CARI RESEP
              _buildCeiShowcase(
                key: _searchNormalKey,
                title: '3. Masak Dari Bahan Ini',
                description: 'Cari resep yang BISA dimasak pake bahan-bahan di atas.',
                shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), // Sesuaikan bentuk tombol
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ElevatedButton.icon(
                    icon: _isSearching
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(isOffline ? Icons.wifi_off : Icons.soup_kitchen),
                    label: Text(_isSearching ? 'Mencari...' : isOffline ? 'Offline' : 'Cari Resep dari Pantry'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: isOffline ? Colors.grey[700] : null, 
                    ),
                    onPressed: _isLoading || _isSearching || isOffline ? null : _searchRecipes,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Isi Kulkas Lo",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                      ),
                    ),
                    if (!_isLoading && _pantryBox.isNotEmpty && !isOffline)
                      TextButton.icon(
                        onPressed: _clearAllPantry,
                        icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.redAccent),
                        label: const Text("Hapus Semua", style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              
              // LIST PANTRY
              Expanded(
                child: _buildCeiShowcase(
                  key: _pantryListKey,
                  title: '2. Cek Dapur Lo',
                  description: 'Bahan-bahan yang udah lo tambahin bakal nongol di sini.',
                  shapeBorder: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ValueListenableBuilder(
                          valueListenable: _pantryBox.listenable(),
                          builder: (context, Box<String> box, _) {
                            if (box.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // PAKE VISUAL KOSONG CHEF CEI
                                    Image.asset(
                                      ChefCeiAssets.kosong,
                                      width: 150, 
                                      fit: BoxFit.contain
                                    ),
                                    const SizedBox(height: 16),
                                    const Text('Pantry masih kosong melompong.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                                    const SizedBox(height: 8),
                                    const Text('Yuk isi bahan dulu!', style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              );
                            }
                            final keys = box.keys.toList();
                            return ListView.builder(
                              itemCount: box.length,
                              padding: const EdgeInsets.only(bottom: 80), 
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
            ],
          ),
          
          // REPO BUTTON (Custom Widget)
          // Asumsi RepoFloatingButton bentuknya lingkaran/oval
          _buildCeiShowcase(
            key: _repoKey,
            title: 'Resep Favorit',
            description: 'Kumpulan resep yang udah lo simpen ada di sini.',
            child: RepoFloatingButton(
              showcaseKey: GlobalKey(), // Key dummy
              onReturn: () => _loadUserStats(), 
            ),
          ),
        ],
      ),
      
      // TOMBOL AI GENERATE
      floatingActionButton: _buildCeiShowcase(
        key: _generateAIKey,
        title: '7. Tanya Chef Cei!',
        description: 'Klik ini biar Chef Cei bikinin resep baru yang unik khusus buat lo!',
        shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)), // Extended FAB biasanya lonjong
        child: FloatingActionButton.extended(
          onPressed: () {
            if (isOffline) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kamu lagi offline! Fitur AI butuh internet, Sob.'), backgroundColor: Colors.orange));
            } else {
               Navigator.pushNamed(context, AppRoutes.generateRecipeRoute).then((_) => _loadUserStats()); 
            }
          },
          label: Text(isOffline ? 'Offline' : 'Buat Resep dengan AI'),
          icon: Icon(isOffline ? Icons.wifi_off : Icons.psychology_alt),
          backgroundColor: isOffline ? Colors.grey : Colors.blueAccent,
          foregroundColor: Colors.white,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}