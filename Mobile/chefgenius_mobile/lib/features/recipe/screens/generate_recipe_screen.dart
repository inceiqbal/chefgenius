import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/widgets/custom_app_bar.dart';
import '../../../app/widgets/ai_loading_dialog.dart';
import '../../../app/data/models/recipe_model.dart';
import '../../../app/data/providers/generated_recipe_provider.dart';
import '../../../app/data/providers/connectivity_provider.dart';
import '../../../app/data/providers/language_provider.dart';
import '../../../app/widgets/offline_banner.dart';
import '../widgets/recipe_card.dart';
import '../../../app/data/utils/generation_constants.dart';
import '../../../app/data/utils/recipe_utils.dart';
import '../widgets/generator_widgets.dart'; 
import '../../../app/config/chef_cei_assets.dart';
import '../../../app/services/gemini_proxy_service.dart';

// --- WRAPPER CLASS (Mirip PantryScreenWithShowcase) ---
// DEPRECATED: Sudah dipindah ke dalam GenerateRecipeScreen
// class GenerateRecipeScreenWithShowcase extends StatelessWidget { ... }

// --- MAIN SCREEN ---
class GenerateRecipeScreen extends StatefulWidget {
  static const String showcaseKey = 'hasSeenAiShowcase';
  final bool isVisible;
  const GenerateRecipeScreen({super.key, this.isVisible = false});

  @override
  State<GenerateRecipeScreen> createState() => _GenerateRecipeScreenState();
}

class _GenerateRecipeScreenState extends State<GenerateRecipeScreen> {
  final TextEditingController _promptController = TextEditingController();
  final supabase = Supabase.instance.client;
  final _geminiProxy = GeminiProxyService();

  // --- SHOWCASE KEYS (Instance variables) ---
  final GlobalKey _promptKey = GlobalKey();
  final GlobalKey _personaKey = GlobalKey();
  final GlobalKey _cuisineKey = GlobalKey();
  final GlobalKey _optionsKey = GlobalKey();
  final GlobalKey _buttonKey = GlobalKey();

  final ScrollController _scrollController = ScrollController();

  bool _isOnCooldown = false;
  Timer? _cooldownTimer;
  int _cooldownSeconds = 10;
  
  // Flag untuk auto start tour
  bool _shouldAutoStartTour = false;

  int _selectedRecipeCount = 1;

  String _selectedCountry = "Any";
  String _selectedRegion = "Any";
  bool _showRegionDropdown = false;

  int _userLevel = 0;
  String _selectedPersonaKey = "standard";
  List<String> _userDietPreferences = [];

  // --- INITIALIZATION ---
  @override
  void initState() {
    super.initState();
    // API Key sekarang tersimpan aman di server (Edge Function)
    // Tidak ada lagi API key di client

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<GeneratedRecipeProvider>().setError("");
        if (widget.isVisible) {
          _checkAndStartTour();
        }
      }
    });

    _loadUserData();
  }

  @override
  void didUpdateWidget(GenerateRecipeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isVisible && widget.isVisible) {
      _checkAndStartTour();
      _loadUserData(); // Reload data saat layar aktif kembali
    }
  }

  // Cek apakah perlu mulai tur otomatis
  Future<void> _checkAndStartTour() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool hasSeenShowcase =
          prefs.getBool(GenerateRecipeScreen.showcaseKey) ?? false;
      
      if (!hasSeenShowcase && mounted) {
        setState(() {
          _shouldAutoStartTour = true;
        });
      }
    } catch (e) {
      debugPrint("Gagal cek SharedPreferences: $e");
    }
  }

  // Fungsi buat start tour (bisa dipanggil manual atau auto)
  void _startTour(BuildContext ctx) async {
    final isOffline = context.read<ConnectivityProvider>().isOffline;
    
    // FIX: Scroll ke atas dulu sebelum memulai tour agar step 1 terlihat
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0, // Scroll ke posisi paling atas
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    List<GlobalKey> keys = [
      _promptKey,
      if (!isOffline) _personaKey, // Skip persona kalau offline
      _cuisineKey,
      _optionsKey,
      _buttonKey,
    ];

    ShowCaseWidget.of(ctx).startShowCase(keys);
  }

  // Simpan status selesai
  Future<void> _onShowcaseComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(GenerateRecipeScreen.showcaseKey, true);
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final xp = prefs.getInt('user_xp') ?? 0;
    final diets = prefs.getStringList('user_diet_preferences') ?? [];
    final currentUserEmail = supabase.auth.currentUser?.email;
    const String adminEmail = "inceiqbals6@gmail.com";

    if (mounted) {
      setState(() {
        if (currentUserEmail == adminEmail) {
          _userLevel = 999; // Super User
        } else {
          _userLevel = xp ~/ GenerationConstants.xpPerLevel;
        }
        _userDietPreferences = diets;

        if (GenerationConstants.personas[_selectedPersonaKey]!['minLevel'] > _userLevel) {
          _selectedPersonaKey = "standard";
        }
      });
    }
  }

  // --- COOLDOWN LOGIC ---
  void _startCooldown() {
    if (!mounted) return;
    setState(() {
      _isOnCooldown = true;
      _cooldownSeconds = 10;
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds > 1) {
        setState(() {
          _cooldownSeconds--;
        });
      } else {
        timer.cancel();
        setState(() {
          _isOnCooldown = false;
        });
      }
    });
  }

  void _showAiLimitInfoDialog() {
    final lang = context.read<LanguageProvider>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lang.getText('ai_limit_title')),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text(lang.getText('ai_limit_desc_1')),
              Text(lang.getText('ai_limit_desc_2')),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text(lang.getText('ai_limit_btn')),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // --- DIET RULES LOGIC ---
  String _getStrictDietRules(List<String> selectedDiets) {
    if (selectedDiets.isEmpty) return "";
    final diets = selectedDiets.join(", ");
    return "User has strict diet: $diets. IF the user request conflicts with this (e.g. 'Chicken' but diet is 'Vegan'), YOU MUST SUBSTITUTE the ingredient. AND in the 'description', you MUST explain: 'Replacing [original] with [substitute] because [reason]'.";
  }

  // Conservative halal validator
  // Returns: 'Halal', 'Non-Halal (Detected)', or 'Unknown'
  String _validateHalalConservative(Map<String, dynamic> item) {
    try {
      final List<String> tokens = [];

      void addToken(dynamic v) {
        if (v == null) return;
        if (v is String) {
          tokens.add(v.toLowerCase());
        } else if (v is List) {
          for (var e in v) {
            if (e == null) continue;
            tokens.add(e.toString().toLowerCase());
          }
        } else if (v is Map) {
          // If ingredient object, try name field(s)
          if (v.containsKey('name')) {
            tokens.add(v['name'].toString().toLowerCase());
          } else {
            for (var val in v.values) {
              if (val != null) tokens.add(val.toString().toLowerCase());
            }
          }
        } else {
          tokens.add(v.toString().toLowerCase());
        }
      }

      addToken(item['title']);
      addToken(item['description']);
      addToken(item['main_ingredients']);
      addToken(item['steps']);
      addToken(item['all_ingredients']);

      final content = tokens.join(' ');

      // Keywords that confidently indicate non-halal
      final nonHalal = [
        'pork', 'babi', 'bacon', 'ham', 'lard', 'pancetta', 'salami', 'porchetta', 'blood', 'blood sausage',
        'alcohol', 'wine', 'beer', 'vodka', 'whiskey', 'rum', 'brandy', 'sake', 'soju', 'tequila'
      ];

      for (var k in nonHalal) {
        if (content.contains(k)) return 'Non-Halal (Detected)';
      }

      // Known clearly-halal ingredients
      final halalKnown = [
        'chicken', 'ayam', 'beef', 'sapi', 'lamb', 'domba', 'goat', 'kambing', 'mutton',
        'fish', 'ikan', 'shrimp', 'udang', 'prawn', 'salmon', 'tuna', 'tilapia', 'egg', 'telur', 'tofu', 'tempe', 'tempeh'
      ];

      for (var k in halalKnown) {
        if (content.contains(k)) return 'Halal';
      }

      // Trust explicit AI label only if it contains 'halal' and nothing non-halal detected
      final rawLabel = item['halal_status']?.toString() ?? '';
      if (rawLabel.toLowerCase().contains('halal')) return 'Halal';

      // Otherwise be conservative
      return 'Unknown';
    } catch (e) {
      return item['halal_status']?.toString() ?? 'Unknown';
    }
  }

  // --- GENERATE RECIPE LOGIC ---
  Future<void> _generateRecipe() async {
    final lang = context.read<LanguageProvider>();

    // CEK SANKSI USER
    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
       final profile = await supabase.from('profiles').select('warning_level').eq('id', userId).maybeSingle();
       if (profile != null && (profile['warning_level'] ?? 0) >= 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Fitur AI dibatasi sementara (Sanksi Akun)."), backgroundColor: Colors.orange),
          );
          return;
       }
    }

    if (context.read<ConnectivityProvider>().isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(lang.getText('offline_msg')),
          backgroundColor: Colors.orange));
      return;
    }

    final provider = context.read<GeneratedRecipeProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (_promptController.text.trim().isEmpty) {
      scaffoldMessenger.showSnackBar(SnackBar(
          content: Text(lang.getText('input_idea_msg'))));
      return;
    }

    // API Key sekarang tersimpan aman di server Edge Function
    // Tidak perlu cek API key lagi di client

    provider.startLoading();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AiLoadingDialog(
        text: lang.getText('thinking_msg'),
        imagePath: ChefCeiAssets.mikir,
      ),
    );

    try {
      final userPrompt = _promptController.text.trim();
      final recipeCount = _selectedRecipeCount;

      String cuisineRule = "Cuisine: Any.";
      if (_selectedCountry != "Any") {
        if (_selectedCountry == "Indonesia" && _selectedRegion != "Any") {
          cuisineRule = "Cuisine: Must be '$_selectedRegion' region of 'Indonesia'.";
        } else {
          cuisineRule = "Cuisine: Must be '$_selectedCountry'.";
        }
      }

      String personaInstruction = GenerationConstants.personas[_selectedPersonaKey]!['instruction'];
      
      // Apply Diet Rules only if Level >= 5
      String dietRule = "";
      if (_userLevel >= 5) {
        dietRule = _getStrictDietRules(_userDietPreferences);
      }

      // --- PROMPT ---
      final prompt = """
      Role: Professional Chef "Chef Genius".
      Task: Create $recipeCount JSON recipes based on user request: "$userPrompt".
      
      CRITICAL RULES (MUST FOLLOW):
      1. **LANGUAGE ADAPTATION**: 
         - DETECT the language of the user's request ("$userPrompt").
         - OUTPUT the entire recipe (Title, Description, Ingredients, Steps) in the SAME LANGUAGE as the request.
      
      2. **CONTEXT & CONSTRAINTS**:
         - $cuisineRule
         - Persona: $personaInstruction
      
      3. **DIET ENFORCEMENT & SUBSTITUTION**:
         - $dietRule
         - If you make a substitution, explicitly mention it in the 'description' field.
      
      4. **NUTRITION DATA (MANDATORY)**: 
         - DO NOT put nutrition info inside the 'description' text.
         - YOU MUST create a separate 'nutrition' object for EACH recipe containing:
           - 'calories' (e.g. "350 kcal")
           - 'protein' (e.g. "25g")
           - 'carbs' (e.g. "10g")
           - 'fat' (e.g. "12g")
         - If unknown, use "-".
      
      Output: LIST of JSON.
      Fields: 
      - title (string)
      - description (string, engaging, max 2 sentences)
      - duration (string)
      - servings (string)
      - main_ingredients (list of string)
      - all_ingredients (list of objects: {name, quantity})
      - steps (list of string)
      - halal_status (string: "Halal"/"Non-Halal")
      - nutrition (object: {calories, protein, carbs, fat})
      
      Error if unrelated to food: {"error": "Topik diluar keahlian masak."}
      """;

      // Panggil Gemini via Proxy (API Key aman di server)
      final response = await _geminiProxy.generateContent(prompt: prompt);

      if (response == null) {
        throw Exception('Tidak ada response dari server');
      }

      // Parse response from proxy
      String jsonString = "[]";
      if (response['candidates'] != null && 
          (response['candidates'] as List).isNotEmpty &&
          response['candidates'][0]['content'] != null &&
          response['candidates'][0]['content']['parts'] != null) {
        jsonString = response['candidates'][0]['content']['parts'][0]['text'] ?? "[]";
      }
      
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
        provider.setError(jsonResult['error']);
        scaffoldMessenger.showSnackBar(SnackBar(content: Text(jsonResult['error']), backgroundColor: Colors.orangeAccent));
        return;
      }

      List<Recipe> recipes = [];
      if (jsonResult is List) {
        for (var item in jsonResult) {
          if (item is Map<String, dynamic>) {
            // Apply conservative halal validation before constructing Recipe
            try {
              final validatedStatus = _validateHalalConservative(item);
              item['halal_status'] = validatedStatus;
            } catch (e) {
              // If validator fails for any reason, fall back to whatever AI returned
            }

            final cleanItem = RecipeUtils.fixRecipeFormat(item);
            recipes.add(Recipe.fromJson(cleanItem, isGeneratedByAi: true));
          }
        }
      } else if (jsonResult is Map<String, dynamic>) {
        try {
          final validatedStatus = _validateHalalConservative(jsonResult);
          jsonResult['halal_status'] = validatedStatus;
        } catch (e) {}

        final cleanItem = RecipeUtils.fixRecipeFormat(jsonResult);
        recipes.add(Recipe.fromJson(cleanItem, isGeneratedByAi: true));
      }

      // FIX: Pastikan jumlah resep tidak melebihi yang diminta user
      if (recipes.length > _selectedRecipeCount) {
        recipes = recipes.sublist(0, _selectedRecipeCount);
      }

      if (!mounted) return;
      navigator.pop();
      _startCooldown();
      provider.setRecipes(recipes);
      
      // Tampilkan notifikasi sukses
      scaffoldMessenger.showSnackBar(SnackBar(
        content: Text(lang.getText('success_msg').replaceAll('@count', recipes.length.toString())),
        backgroundColor: Colors.green,
      ));

    } catch (e) {
      if (!mounted) return;
      navigator.pop();
      _startCooldown();
      
      String errorMsg = e.toString();
      String friendlyMsg = "Waduh, Chef Cei lagi pusing nih. Coba lagi nanti ya!"; // Default

      if (errorMsg.contains("ResourceExhausted") || errorMsg.contains("429") || errorMsg.contains("Overloaded")) {
        friendlyMsg = "Dapur lagi rame banget! Chef Cei butuh istirahat sebentar. Coba 1 menit lagi ya!";
      } else if (errorMsg.contains("Safety") || errorMsg.contains("blocked")) {
        friendlyMsg = "Waduh, request kamu agak bahaya nih buat dapur. Coba ganti kata-katanya ya!";
      } else if (errorMsg.contains("SocketException") || errorMsg.contains("Network") || errorMsg.contains("No address associated")) {
        friendlyMsg = "Yah, sinyalnya ilang-ilangan kayak dia. Cek internet kamu dulu yuk!";
      } else if (errorMsg.contains("API key")) {
        friendlyMsg = "Kunci dapur (API Key) bermasalah nih. Lapor ke admin ya!";
      } else if (errorMsg.contains("FormatException")) {
        friendlyMsg = "Chef Cei salah nulis resep nih. Coba generate ulang ya!";
      }

      provider.setError(friendlyMsg);
      scaffoldMessenger.showSnackBar(SnackBar(content: Text(friendlyMsg), backgroundColor: Colors.orange));
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final provider = context.watch<GeneratedRecipeProvider>();
    final isGenerating = provider.isGenerating;
    final generatedRecipes = provider.generatedRecipes;
    final isOffline = context.watch<ConnectivityProvider>().isOffline;

    // WRAP DENGAN SHOWCASE WIDGET DI SINI
    return ShowCaseWidget(
      onStart: (index, dynamic key) async {
        if (key is! GlobalKey) return;
        
        // Untuk Execute button, scroll ke bawah DULU lalu tunggu
        if (key == _buttonKey) {
          if (_scrollController.hasClients) {
            // Scroll ke posisi maksimum
            await _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
            // Tunggu frame berikutnya agar layout terupdate
            await Future.delayed(const Duration(milliseconds: 100));
            // Force rebuild showcase dengan setState
            if (mounted) {
              setState(() {});
            }
          }
        } else if (key.currentContext != null) {
          // Untuk widget lain, gunakan ensureVisible
          await Future.delayed(const Duration(milliseconds: 100));
          Scrollable.ensureVisible(
            key.currentContext!,
            duration: const Duration(milliseconds: 300),
            alignment: 0.3,
            curve: Curves.easeInOut,
          );
        }
      },
      onComplete: (index, dynamic key) {
        if (key is! GlobalKey) return;
        if (key == _buttonKey) {
          _onShowcaseComplete();
        }
      },
      onDismiss: ([dynamic key]) {
        _onShowcaseComplete();
      },
      blurValue: 1,
      builder: (innerContext) {
        // Cek auto start
        if (_shouldAutoStartTour) {
          _shouldAutoStartTour = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
             // Tambah delay dikit biar layout ready 100%
             Future.delayed(const Duration(milliseconds: 300), () {
                if (innerContext.mounted) {
                   _startTour(innerContext);
                }
             });
          });
        }

        // Jika halaman tidak terlihat, pastikan showcase dimatikan
        if (!widget.isVisible) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
             ShowCaseWidget.of(innerContext).dismiss();
          });
        }

        return Scaffold(
          appBar: CustomAppBar(
            title: lang.getText('gen_appbar_title'),
            actions: [
              IconButton(
                icon: const Icon(Icons.help_outline),
                tooltip: lang.getText('help_btn'),
                // PENTING: Gunakan innerContext dari builder ShowCaseWidget
                onPressed: () => _startTour(innerContext), 
              ),
            ],
          ),
          body: Column(
            children: [
              const OfflineBanner(),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. PROMPT INPUT
                      PromptInputSection(
                        showcaseKey: _promptKey,
                        controller: _promptController,
                        isOffline: isOffline,
                        onInfoPressed: _showAiLimitInfoDialog,
                        userDietPreferences: _userDietPreferences,
                        userLevel: _userLevel,
                        onSettingsChanged: _loadUserData,
                      ),

                      const SizedBox(height: 24),

                      // 2. PERSONA SELECTOR
                      PersonaSelectorWidget(
                        showcaseKey: _personaKey,
                        selectedPersonaKey: _selectedPersonaKey,
                        userLevel: _userLevel,
                        isOffline: isOffline,
                        onSelect: (key) => setState(() => _selectedPersonaKey = key),
                      ),

                      // 3. SETTINGS
                      RecipeSettingsSection(
                        cuisineKey: _cuisineKey,
                        optionsKey: _optionsKey,
                        selectedCountry: _selectedCountry,
                        selectedRegion: _selectedRegion,
                        selectedCount: _selectedRecipeCount,
                        isOffline: isOffline,
                        showRegionDropdown: _showRegionDropdown,
                        userLevel: _userLevel, // Pass user level
                        onCountryChanged: (val) {
                          setState(() {
                            _selectedCountry = val ?? "Any";
                            _selectedRegion = "Any";
                            _showRegionDropdown = (val == "Indonesia");
                          });
                        },
                        onRegionChanged: (val) => setState(() => _selectedRegion = val ?? "Any"),
                        onCountChanged: (val) => setState(() => _selectedRecipeCount = val),
                      ),

                      const SizedBox(height: 16),

                      // INFO BOX
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Theme.of(context).colorScheme.primaryContainer)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(lang.getText('gen_info_box_title'),
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            RichText(
                              text: TextSpan(
                                style: Theme.of(context).textTheme.bodySmall,
                                children: [
                                  const TextSpan(text: "• "),
                                  TextSpan(text: lang.getText('gen_info_bullet_1'), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  TextSpan(text: lang.getText('gen_info_text_1')),
                                  const TextSpan(text: "• "),
                                  TextSpan(text: lang.getText('gen_info_bullet_2'), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  TextSpan(text: lang.getText('gen_info_text_2')),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 4. GENERATE BUTTON
                      GenerateButtonSection(
                        showcaseKey: _buttonKey,
                        isGenerating: isGenerating,
                        isOnCooldown: _isOnCooldown,
                        isOffline: isOffline,
                        cooldownSeconds: _cooldownSeconds,
                        personaLabel: GenerationConstants.personas[_selectedPersonaKey]!['label'],
                        onPressed: _generateRecipe,
                      ),

                      const SizedBox(height: 40),

                      // RESULT LIST
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
                              Image.asset(
                                ChefCeiAssets.kosong,
                                width: 150,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                lang.getText('gen_empty_state'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16, color: Colors.grey),
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
    );
  }
}