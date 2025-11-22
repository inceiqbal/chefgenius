import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../../app/widgets/custom_app_bar.dart';
import '../../../app/widgets/ai_loading_dialog.dart';
import '../../../app/data/models/recipe_model.dart';
import '../../../app/data/providers/generated_recipe_provider.dart';
import '../../../app/data/providers/connectivity_provider.dart';
import '../../../app/widgets/offline_banner.dart';
import '../widgets/recipe_card.dart'; 
import '../../../app/data/utils/generation_constants.dart'; 
import '../../../app/data/utils/recipe_utils.dart';
import '../widgets/generator_widgets.dart'; 
import '../../../app/config/gemini_config.dart';
import '../../../app/config/chef_cei_assets.dart'; // ASET CHEF CEI

class GenerateRecipeScreenWithShowcase extends StatelessWidget {
  const GenerateRecipeScreenWithShowcase({super.key});
  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      onStart: (index, key) {},
      onComplete: (index, key) {
        if (key == _GenerateRecipeScreenState._buttonKey) {
          _GenerateRecipeScreenState._onShowcaseComplete();
        }
      },
      onDismiss: (key) {
        _GenerateRecipeScreenState._onShowcaseComplete();
      },
      blurValue: 1,
      builder: (context) => const GenerateRecipeScreen(),
    );
  }
}

class GenerateRecipeScreen extends StatefulWidget {
  static const String showcaseKey = 'hasSeenAiShowcase';
  const GenerateRecipeScreen({super.key});
  @override
  State<GenerateRecipeScreen> createState() => _GenerateRecipeScreenState();
}

class _GenerateRecipeScreenState extends State<GenerateRecipeScreen> {
  final TextEditingController _promptController = TextEditingController();
  late final GenerativeModel model;

  static final GlobalKey _promptKey = GlobalKey();
  static final GlobalKey _personaKey = GlobalKey();
  static final GlobalKey _cuisineKey = GlobalKey();
  static final GlobalKey _optionsKey = GlobalKey();
  static final GlobalKey _buttonKey = GlobalKey();

  bool _isOnCooldown = false;
  Timer? _cooldownTimer;
  int _cooldownSeconds = 10;

  int _selectedRecipeCount = 1; 
  String _selectedCountry = "Bebas";
  String _selectedRegion = "Bebas";
  bool _showRegionDropdown = false;

  int _userLevel = 0;
  String _selectedPersonaKey = "standard"; 
  List<String> _userDietPreferences = [];

  static Future<void> _onShowcaseComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(GenerateRecipeScreen.showcaseKey, true);
  }

  // --- HELPER BARU: VISUAL KARTUN CHEF CEI ---
  Widget _buildCeiShowcase({
    required GlobalKey key,
    required String title,
    required String description,
    required Widget child,
    ShapeBorder? shapeBorder, 
  }) {
    return Showcase.withWidget(
      key: key,
      targetShapeBorder: shapeBorder ?? const CircleBorder(),
      container: Container(
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
              height: 100,
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
  // ------------------------------------------

  Future<void> _checkIfFirstTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool hasSeenShowcase =
          prefs.getBool(GenerateRecipeScreen.showcaseKey) ?? false;
      if (!hasSeenShowcase && mounted) {
        ShowCaseWidget.of(context).startShowCase([
          _promptKey, _personaKey, _cuisineKey, _optionsKey, _buttonKey,
        ]);
      }
    } catch (e) {
      debugPrint("Gagal cek SharedPreferences: $e");
    }
  }
  
  void _startThisPageTour() {
    if (mounted) {
      ShowCaseWidget.of(context).startShowCase([
        _promptKey, _personaKey, _cuisineKey, _optionsKey, _buttonKey,
      ]);
    }
  }

  void _showAiLimitInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kenapa Resep Saya Ditolak?'),
        content: const SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text('Chef Cei kami punya "Filter Keamanan" yang ketat.\n'),
              Text('Dia akan menolak prompt yang dianggap membahas topik sensitif (kekerasan, ilegal, dll).\n'),
              Text('Tapi tenang, resep bahan makanan umum (seperti Babi) tetap aman kok!'),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Ngerti, Bos!'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Inisialisasi Model dengan API Key Rotasi
    model = GenerativeModel(
      model: 'gemini-2.5-flash-preview-09-2025', 
      apiKey: GeminiConfig.apiKey,
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
      ],
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<GeneratedRecipeProvider>().setError("");
      }
      _checkIfFirstTime();
    });

    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); 
    final xp = prefs.getInt('user_xp') ?? 0;
    final diets = prefs.getStringList('user_diet_preferences') ?? [];
    
    if (mounted) {
      setState(() {
        _userLevel = xp ~/ GenerationConstants.xpPerLevel;
        _userDietPreferences = diets;
        if (GenerationConstants.personas[_selectedPersonaKey]!['minLevel'] > _userLevel) {
          _selectedPersonaKey = "standard";
        }
      });
    }
  }

  void _startCooldown() {
    if (!mounted) return;
    setState(() { _isOnCooldown = true; _cooldownSeconds = 10; });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_cooldownSeconds > 1) {
        setState(() { _cooldownSeconds--; });
      } else {
        timer.cancel();
        setState(() { _isOnCooldown = false; });
      }
    });
  }

  Future<void> _generateRecipe() async {
    if (context.read<ConnectivityProvider>().isOffline) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kamu lagi offline! Fitur AI butuh internet, Sob.'), backgroundColor: Colors.orange));
       return;
    }

    final provider = context.read<GeneratedRecipeProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (_promptController.text.trim().isEmpty) {
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Tuliskan ide resep atau bahan dulu!')));
      return;
    }
    
    if (GeminiConfig.apiKey.isEmpty) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('API Key Google AI tidak ditemukan!'), backgroundColor: Colors.red));
      return;
    }

    provider.startLoading();
    showDialog(
      context: context,
      barrierDismissible: false,
      // PAKE VISUAL CHEF CEI MIKIR
      builder: (BuildContext dialogContext) => const AiLoadingDialog(
        text: "Chef Cei lagi mikir resep...",
        imagePath: ChefCeiAssets.mikir,
      ),
    );

    try {
      final userPrompt = _promptController.text.trim();
      final recipeCount = _selectedRecipeCount;

      String cuisineRule = "Cuisine: Any.";
      if (_selectedCountry != "Bebas") {
        if (_selectedCountry == "Indonesia" && _selectedRegion != "Bebas") {
          cuisineRule = "Cuisine: Must be '$_selectedRegion' region of 'Indonesia'.";
        } else {
          cuisineRule = "Cuisine: Must be '$_selectedCountry'.";
        }
      }
      
      String personaInstruction = GenerationConstants.personas[_selectedPersonaKey]!['instruction'];
      
      String dietRule = "";
      if (_userDietPreferences.isNotEmpty) {
        String diets = _userDietPreferences.join(", ");
        dietRule = "DIET RESTRICTION: No ingredients related to: $diets.";
      }

      // PROMPT HEMAT TOKEN & STRICT
      final prompt = """
      Role: Professional Chef "Chef Genius".
      Task: Create $recipeCount JSON recipes for: "$userPrompt".
      
      CRITICAL RULES (MUST FOLLOW):
      1. **LANGUAGE**: OUTPUT MUST BE IN INDONESIAN (BAHASA INDONESIA).
         - Even if user types "Egg", you MUST write "Telur".
         - Even if user types "Rice", you MUST write "Nasi".
         - NO ENGLISH INGREDIENT NAMES ALLOWED in JSON output.
      
      2. **CONTEXT**:
         - $cuisineRule
         - $dietRule
         - Persona: $personaInstruction
      
      3. **NUTRITION**: Include est. calories/protein/carbs in 'description'.
      
      Output: LIST of JSON.
      Fields: title, description, duration, servings, main_ingredients, all_ingredients (name, quantity), steps, halal_status.
      
      Error if unrelated: {"error": "Topik diluar keahlian masak."}
      """;

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      String jsonString = response.text ?? "[]";
      final jsonMatch = RegExp(r'\[.*\]|\{.*\}', dotAll: true).firstMatch(jsonString);
      if (jsonMatch != null) {
        jsonString = jsonMatch.group(0)!;
      } else {
         jsonString = jsonString.replaceAll('```json\n', '').replaceAll('\n```', '').trim();
      }

      final dynamic jsonResult = jsonDecode(jsonString);

      if (jsonResult is Map && jsonResult.containsKey('error')) {
        if (!mounted) return;
        navigator.pop();
        _startCooldown();
        final String errorMessage = jsonResult['error'] ?? "Terjadi kesalahan topik.";
        provider.setError(errorMessage);
        scaffoldMessenger.showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: Colors.blueAccent));
        return;
      }

      List<Recipe> recipes = [];
      if (jsonResult is List) {
        for (var item in jsonResult) {
          if (item is Map<String, dynamic>) {
            final cleanItem = RecipeUtils.fixRecipeFormat(item);
            recipes.add(Recipe.fromJson(cleanItem, isGeneratedByAi: true));
          }
        }
      } else if (jsonResult is Map<String, dynamic>) {
        final cleanItem = RecipeUtils.fixRecipeFormat(jsonResult);
        recipes.add(Recipe.fromJson(cleanItem, isGeneratedByAi: true));
      } else {
        throw Exception("AI mengembalikan format data yang salah.");
      }

      if (!mounted) return;
      navigator.pop();
      _startCooldown();
      provider.setRecipes(recipes);

      if (mounted && recipes.isNotEmpty) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('${recipes.length} resep berhasil dibuat oleh ${GenerationConstants.personas[_selectedPersonaKey]!['label']}!')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      navigator.pop();
      _startCooldown();
      
      String friendlyMessage = 'Waduh, gagal memproses resep: ${e.toString()}';
      Color snackBarColor = Colors.red;

      String errorStr = e.toString().toLowerCase();

      if (errorStr.contains('quota') || errorStr.contains('429')) {
         friendlyMessage = "GOKIL! Jatah AI harian habis atau server lagi sibuk berat (Overloaded). Coba beberapa saat lagi ya!";
         snackBarColor = Colors.orange[900]!;
      } else if (errorStr.contains('503') || errorStr.contains('overloaded')) {
         friendlyMessage = "Koki AI lagi pusing (Server Overloaded). Kasih dia napas bentar, terus coba lagi!";
         snackBarColor = Colors.orange[900]!;
      } else if (errorStr.contains('safety')) {
         friendlyMessage = "Waduh, resep ini kena sensor keamanan Google. Coba ganti kata-katanya ya!";
         snackBarColor = Colors.purple;
      }

      provider.setError(friendlyMessage);
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(friendlyMessage), backgroundColor: snackBarColor, duration: const Duration(seconds: 5)),
      );
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _cooldownTimer?.cancel();
    if (mounted) {
      ShowCaseWidget.of(context).dismiss();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GeneratedRecipeProvider>();
    final isGenerating = provider.isGenerating;
    final generatedRecipes = provider.generatedRecipes;
    final isOffline = context.watch<ConnectivityProvider>().isOffline;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Buat Resep dengan AI',
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Bantuan',
            onPressed: _startThisPageTour,
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Ide Resep untuk Chef Cei:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  
                  // 1. SHOWCASE PROMPT (INPUT)
                  _buildCeiShowcase(
                    key: _promptKey,
                    title: '1. Tulis Ide Anda',
                    description: 'Ketik bahan-bahan atau tujuan diet yang lo mau.',
                    shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _promptController,
                          enabled: !isOffline,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: isOffline ? 'Offline (Fitur AI dimatikan)' : 'Misal: "Resep dada ayam enak tapi rendah kalori"',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[100],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            icon: Icon(Icons.info_outline, size: 18, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                            label: Text("Info Batasan & Filter AI", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
                            onPressed: _showAiLimitInfoDialog,
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                          ),
                        ),
                        
                        if (_userDietPreferences.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.orange, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text("Filter Aktif: ${_userDietPreferences.join(', ')}", style: const TextStyle(fontSize: 12, color: Colors.orange)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24), 

                  // 2. SHOWCASE PERSONA (WRAPPER)
                  _buildCeiShowcase(
                    key: _personaKey,
                    title: '2. Pilih Koki',
                    description: 'Pilih kepribadian Chef Cei yang bakal ngelayanin lo!',
                    child: PersonaSelectorWidget(
                      showcaseKey: GlobalKey(), // Pass dummy key biar yang di dalem gak aktif
                      selectedPersonaKey: _selectedPersonaKey,
                      userLevel: _userLevel,
                      isOffline: isOffline,
                      onSelect: (key) => setState(() => _selectedPersonaKey = key),
                    ),
                  ),

                  RecipeSettingsSection(
                    cuisineKey: _cuisineKey,
                    optionsKey: _optionsKey,
                    selectedCountry: _selectedCountry,
                    selectedRegion: _selectedRegion,
                    selectedCount: _selectedRecipeCount,
                    isOffline: isOffline,
                    showRegionDropdown: _showRegionDropdown,
                    onCountryChanged: (val) {
                      setState(() {
                        _selectedCountry = val ?? "Bebas";
                        _selectedRegion = "Bebas";
                        _showRegionDropdown = (val == "Indonesia");
                      });
                    },
                    onRegionChanged: (val) => setState(() => _selectedRegion = val ?? "Bebas"),
                    onCountChanged: (val) => setState(() => _selectedRecipeCount = val),
                  ),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Theme.of(context).colorScheme.primaryContainer)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Info Penting (Harap Dibaca!)", style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        RichText(
                          text: TextSpan(
                            style: Theme.of(context).textTheme.bodySmall,
                            children: const [
                              TextSpan(text: "• "),
                              TextSpan(text: "Upgrade Baru (Nutrisi): ", style: TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(text: "Chef Cei sekarang akan otomatis menghitung estimasi Kalori & Nutrisi.\n"),
                              TextSpan(text: "• "),
                              TextSpan(text: "Info Kuota: ", style: TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(text: "Mau minta 1 atau 10 resep, kuota AI yang kepake SAMA AJA.\n"),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  
                  // 3. SHOWCASE TOMBOL EKSEKUSI
                  _buildCeiShowcase(
                    key: _buttonKey,
                    title: '5. Eksekusi!',
                    description: 'Klik tombol ini dan biarkan Chef Cei bekerja!',
                    shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ElevatedButton.icon(
                      icon: isGenerating
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(isOffline ? Icons.wifi_off : Icons.psychology_alt),
                      label: Text(isGenerating
                          ? 'Meracik Resep...'
                          : _isOnCooldown
                              ? 'Tunggu $_cooldownSeconds detik...'
                              : isOffline 
                                  ? 'Offline (Fitur AI Mati)'
                                  : 'Buat Resep (${GenerationConstants.personas[_selectedPersonaKey]!['label']})'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOffline ? Colors.grey : Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: (isGenerating || _isOnCooldown || isOffline) ? null : _generateRecipe,
                    ),
                  ),
                  const SizedBox(height: 40),

                  if (generatedRecipes.isNotEmpty)
                    ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: generatedRecipes.length,
                      itemBuilder: (context, index) {
                        return RecipeCard(recipe: generatedRecipes[index]);
                      },
                    )
                  else if (!isGenerating)
                    Center(
                      child: Column(
                        children: [
                          // PAKE VISUAL CHEF CEI KOSONG
                          Image.asset(
                            ChefCeiAssets.kosong,
                            width: 150,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Belum ada resep yang dibuat.\nMari ciptakan resep baru!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey),
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
    );
  }
}