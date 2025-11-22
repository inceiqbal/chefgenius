import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Buat nyimpen status
import '../../../app/config/routes.dart';

class IntroCeiScreen extends StatefulWidget {
  final String email; // Butuh email buat dilempar ke Pantry nanti
  const IntroCeiScreen({super.key, required this.email});

  @override
  State<IntroCeiScreen> createState() => _IntroCeiScreenState();
}

class _IntroCeiScreenState extends State<IntroCeiScreen> with TickerProviderStateMixin {
  final List<Map<String, dynamic>> _dialogues = [
    {
      "text": "Hai Bestie! 👋\nAkhirnya kamu sampai di sini!",
      "duration": 3000, 
    },
    {
      "text": "Kenalin, aku Cei, asisten dapur pintarmu!",
      "duration": 3000, 
    },
    {
      "text": "Bingung masak apa? Atau males ngetik bahan?",
      "duration": 3500, 
    },
    {
      "text": "Tenang... Aku punya 'Cei Vision'! ✨\nCukup foto, aku yang urus sisanya.",
      "duration": 4500, 
    },
    {
      "text": "Yuk, langsung kita cek dapurmu!",
      "duration": 3000,
    },
  ];

  int _currentIndex = 0;
  Timer? _timer;
  bool _showCeiVisionEffect = false;
  
  late AnimationController _characterController; // Buat napas
  late AnimationController _visionController; // Buat efek mata
  late AnimationController _entranceController; // BUAT MUNCUL PERLAHAN

  @override
  void initState() {
    super.initState();
    
    // 1. Animasi Muncul Perlahan (Fade In + Slide Up)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // 2 detik munculnya pelan
    )..forward();

    // 2. Animasi Napas
    _characterController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // 3. Animasi Mata
    _visionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // Mulai Dialog setelah karakter muncul dikit
    Future.delayed(const Duration(seconds: 1), () {
      _startDialogueSequence();
    });
  }

  void _startDialogueSequence() {
    if (_currentIndex < _dialogues.length) {
      if (_dialogues[_currentIndex]['text'].toString().contains('Cei Vision')) {
        setState(() => _showCeiVisionEffect = true);
      }

      _timer = Timer(Duration(milliseconds: _dialogues[_currentIndex]['duration'] as int), () {
        if (mounted) {
          setState(() {
            _currentIndex++;
          });
          _startDialogueSequence();
        }
      });
    } else {
      _finishIntro();
    }
  }

  // --- LOGIC PINDAH KE PANTRY (SETELAH LOGIN) ---
  Future<void> _finishIntro() async {
    _timer?.cancel();
    
    // 1. Simpan tanda kalau user udah kenalan sama Cei
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenIntroCei', true);

    if (!mounted) return;

    // 2. Masuk ke Pantry (Bawa Email)
    Navigator.pushReplacementNamed(
      context, 
      AppRoutes.pantryRoute, 
      arguments: widget.email
    );
  }

  void _skipIntro() {
    _finishIntro();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _characterController.dispose();
    _visionController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentDialog = _currentIndex < _dialogues.length 
        ? _dialogues[_currentIndex] 
        : _dialogues.last;

    return Scaffold(
      body: Stack(
        children: [
          // 1. BACKGROUND
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF3E0), Color(0xFFFFCC80)], 
              ),
            ),
          ),

          // 2. EFEK CEI VISION 
          if (_showCeiVisionEffect)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: FadeTransition( // Efek muncul alus
                opacity: _entranceController,
                child: Center(
                  child: RotationTransition(
                    turns: _visionController,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                        gradient: RadialGradient(
                          colors: [
                            Colors.orange.withOpacity(0.0),
                            Colors.orange.withOpacity(0.4),
                          ],
                        ),
                      ),
                      child: const Icon(Icons.filter_center_focus, size: 100, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),

          // 3. KARAKTER CEI (MUNCUL PERLAHAN KE TENGAH)
          Positioned(
            bottom: 200, 
            left: 0,
            right: 0,
            child: SlideTransition(
              // Muncul dari bawah pelan-pelan
              position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(CurvedAnimation(
                parent: _entranceController,
                curve: Curves.easeOutBack,
              )),
              child: FadeTransition(
                opacity: _entranceController,
                child: AnimatedBuilder(
                  animation: _characterController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, 5 * _characterController.value), 
                      child: child,
                    );
                  },
                  child: Column(
                    children: [
                      // --- BAGIAN INI YANG AKU PERBAIKI ---
                      Container(
                        height: 350,
                        width: 250,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          image: DecorationImage(
                            // Pake Aset Lokal, bukan NetworkImage
                            image: AssetImage(
                              _showCeiVisionEffect 
                                ? 'assets/images/Chef_Cei/chefceimatadewa.png' // Mode Mata Dewa
                                : 'assets/images/Chef_Cei/chefceiintro.png'    // Mode Biasa
                            ),
                            fit: BoxFit.contain,
                            // Kalau pake aset sendiri yang udah berwarna, gak perlu di-tint oranye lagi
                            // colorFilter: _showCeiVisionEffect 
                            //   ? ColorFilter.mode(Colors.orange.withOpacity(0.2), BlendMode.srcATop) 
                            //   : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 4. DIALOG BOX (MUNCUL BELAKANGAN)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _entranceController, // Dialog juga muncul pelan
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, -5),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Text(
                          "Chef Cei",
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: Text(
                        currentDialog['text'],
                        key: ValueKey<int>(_currentIndex), 
                        style: const TextStyle(
                          fontSize: 22,
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          fontFamily: 'Poppins', 
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _skipIntro,
                          child: Text(
                            "Skip",
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () {
                            if (_currentIndex < _dialogues.length - 1) {
                              _timer?.cancel(); 
                              setState(() {
                                _currentIndex++;
                                _startDialogueSequence(); 
                              });
                            } else {
                              _finishIntro();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(20),
                            elevation: 8,
                          ),
                          child: const Icon(Icons.arrow_forward),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}