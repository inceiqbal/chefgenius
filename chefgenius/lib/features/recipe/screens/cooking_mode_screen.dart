import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 
import '../../../app/services/gemini_tts_service.dart';
import '../../../app/data/models/recipe_model.dart';
import '../../../app/data/providers/connectivity_provider.dart';
import '../../../app/widgets/offline_banner.dart';
import '../widgets/cooking_step_view.dart';
import '../widgets/cooking_checklist_sheet.dart';
import '../widgets/cooking_completion_dialog.dart';

class CookingModeScreen extends StatefulWidget {
  final Recipe recipe;
  const CookingModeScreen({super.key, required this.recipe});

  @override
  State<CookingModeScreen> createState() => _CookingModeScreenState();
}

enum TtsState { playing, stopped, paused, loading }

class _CookingModeScreenState extends State<CookingModeScreen> {
  final GeminiTtsService _ttsService = GeminiTtsService();
  final supabase = Supabase.instance.client; 
  
  late AudioPlayer audioPlayer;
  late PageController _pageController;
  late List<bool> _ingredientCheckedState;
  int _currentPage = 0;
  TtsState _ttsState = TtsState.stopped;
  
  bool _isSaving = false; 

  // KONFIGURASI GAMIFICATION
  static const int xpReward = 50; 
  static const int xpPerLevel = 300; 

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initAudioPlayer();
    _ingredientCheckedState =
        List<bool>.filled(widget.recipe.allIngredients.length, false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfFirstTimeShowDisclaimer();
    });
  }

  void _initAudioPlayer() {
    audioPlayer = AudioPlayer();
    audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          if (state == PlayerState.completed || state == PlayerState.stopped) {
            _ttsState = TtsState.stopped;
          } else if (state == PlayerState.playing) {
            _ttsState = TtsState.playing;
          }
        });
      }
    });
    audioPlayer.onLog.listen((msg) => debugPrint("AudioLog: $msg"));
  }

  Future<void> _checkIfFirstTimeShowDisclaimer() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('hasSeenTtsDisclaimer') ?? false) && mounted) {
      _showDisclaimerDialog(prefs);
    }
  }

  void _showDisclaimerDialog(SharedPreferences prefs) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Info Penting, Sob!'),
        content: const Text(
            'Fitur "Suara AI" butuh internet & ada kuota harian ya.\n\nTapi tenang, suara yang udah didengerin bakal disimpen di HP, jadi selanjutnya GRATIS!'),
        actions: [
          TextButton(
            child: const Text('Siap, Ngerti!'),
            onPressed: () {
              prefs.setBool('hasSeenTtsDisclaimer', true);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _speak() async {
    if (widget.recipe.steps.isEmpty) return;
    if (_ttsState == TtsState.loading) return;

    if (context.read<ConnectivityProvider>().isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Kamu lagi offline! Butuh internet buat download suara pertama kali.'),
          backgroundColor: Colors.orange));
      return;
    }

    if (_ttsState == TtsState.stopped) {
      setState(() => _ttsState = TtsState.loading);
      try {
        String uniqueId;
        if (widget.recipe.id != 0) {
           uniqueId = widget.recipe.id.toString();
        } else {
           uniqueId = "ai_${widget.recipe.title.hashCode}";
        }

        final audioPath = await _ttsService.getAudioFile(
          stepTextRaw: widget.recipe.steps[_currentPage],
          stepIndex: _currentPage,
          recipeId: uniqueId, 
        );

        if (mounted) {
          setState(() => _ttsState = TtsState.playing);
          await audioPlayer.play(DeviceFileSource(audioPath));
        }
      } catch (e) {
        if (mounted) {
          setState(() => _ttsState = TtsState.stopped);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Gagal memutar suara: $e')));
        }
      }
    }
  }

  Future<void> _stop() async {
    if (_ttsState == TtsState.playing || _ttsState == TtsState.loading) {
      await audioPlayer.stop();
      if (mounted) setState(() => _ttsState = TtsState.stopped);
    }
  }

  void _showChecklist() {
    if (widget.recipe.allIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resep ini tidak punya daftar bahan.')));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CookingChecklistSheet(
        ingredients: widget.recipe.allIngredients,
        checkedState: _ingredientCheckedState,
        onCheckChanged: (index, value) {
          setState(() => _ingredientCheckedState[index] = value);
        },
      ),
    );
  }

  // --- FUNGSI UTAMA: SIMPAN KE HISTORY (FULL DATA) & KASIH XP ---
  Future<void> _finishCooking() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        // 1. SIAPIN DATA LENGKAP (Biar Resep AI bisa dibuka lagi nanti)
        final Map<String, dynamic> fullRecipeSnapshot = {
           'title': widget.recipe.title,
           'description': widget.recipe.description,
           'duration': widget.recipe.duration,
           'servings': widget.recipe.servings,
           'image_url': widget.recipe.imageUrl,
           'halal_status': widget.recipe.halalStatus,
           'steps': widget.recipe.steps,
           
           // --- PERBAIKAN DI SINI (FIX toJson ERROR) ---
           // Kita manual mapping biar aman, gak perlu method toJson di model
           'all_ingredients': widget.recipe.allIngredients.map((e) => {
             'name': e.name,
             'quantity': e.quantity
           }).toList(),
           
           'main_ingredients': widget.recipe.mainIngredients,
        };

        // 2. Simpan ke Supabase
        await supabase.from('cooking_history').insert({
          'user_id': user.id,
          'recipe_id': widget.recipe.id,
          'recipe_title': widget.recipe.title,
          'recipe_image_url': widget.recipe.imageUrl,
          'cooked_at': DateTime.now().toIso8601String(),
          'recipe_details': fullRecipeSnapshot,
        });

        // 3. Tambah XP User
        final prefs = await SharedPreferences.getInstance();
        int currentXp = prefs.getInt('user_xp') ?? 0;
        
        // Hitung Level Sebelum nambah XP
        int oldLevel = currentXp ~/ xpPerLevel; // xpPerLevel DIPAKE DI SINI
        
        // Tambah XP
        int newTotalXp = currentXp + xpReward;
        await prefs.setInt('user_xp', newTotalXp);
        
        // Hitung Level Setelah nambah XP
        int newLevel = newTotalXp ~/ xpPerLevel; // DAN DI SINI
        
        if (newLevel > oldLevel) {
          debugPrint("LEVEL UP! Selamat Sob, naik ke Lv.$newLevel");
        }
        
        debugPrint("Berhasil simpan Full History & XP!");
      }
    } catch (e) {
      debugPrint("Waduh error pas nyimpen history: $e");
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
        _showCompletion(); 
      }
    }
  }

  void _showCompletion() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CookingCompletionDialog(
        onClose: () {
          Navigator.of(context).pop(); 
          Navigator.of(context).pop(); 
        },
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.recipe.steps.isEmpty) {
      return Scaffold(
          appBar: AppBar(
              backgroundColor: Colors.transparent, elevation: 0),
          body: const Center(
              child: Text('Resep ini tidak punya langkah-langkah.')));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF121212)
          : Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context)),
        centerTitle: true,
        title: const Text(
            "Mode Masak", 
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
              icon: const Icon(Icons.list_alt_rounded),
              onPressed: _showChecklist),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0.0), 
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              tween: Tween<double>(
                begin: 0,
                end: (_currentPage + 1) / widget.recipe.steps.length,
              ),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                backgroundColor: Colors.grey[800],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                minHeight: 6, 
              ),
            ),
          ),

          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.recipe.steps.length,
              onPageChanged: (int page) {
                setState(() => _currentPage = page);
                _stop();
              },
              itemBuilder: (context, index) {
                return CookingStepView(
                  stepText: widget.recipe.steps[index],
                  stepIndex: index,
                  totalSteps: widget.recipe.steps.length, 
                  onTimerFinished: _stop,
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.black,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                label:
                    const Text('Mundur', style: TextStyle(color: Colors.white)),
                onPressed: _currentPage == 0
                    ? null
                    : () {
                        _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut);
                      },
                style: TextButton.styleFrom(
                    disabledForegroundColor: Colors.grey.withOpacity(0.5)),
              ),
              TextButton.icon(
                icon: _isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber))
                  : const Icon(Icons.arrow_forward_ios, color: Colors.white),
                label: Text(
                  _currentPage == widget.recipe.steps.length - 1
                      ? 'Selesai!'
                      : 'Lanjut',
                  style: TextStyle(
                      color: _currentPage == widget.recipe.steps.length - 1
                          ? Colors.amber
                          : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                onPressed: _isSaving ? null : () {
                  if (_currentPage == widget.recipe.steps.length - 1) {
                    _finishCooking(); 
                  } else {
                    _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        backgroundColor: _ttsState == TtsState.playing
            ? Colors.redAccent
            : (_ttsState == TtsState.loading
                ? Colors.grey
                : Theme.of(context).primaryColor),
        onPressed: _ttsState == TtsState.loading
            ? null
            : (_ttsState == TtsState.playing ? _stop : _speak),
        child: _ttsState == TtsState.loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 3))
            : Icon(_ttsState == TtsState.playing
                ? Icons.stop
                : Icons.volume_up),
      ),
    );
  }
}