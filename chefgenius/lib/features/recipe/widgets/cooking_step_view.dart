import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart'; // Import Lottie

class CookingStepView extends StatefulWidget {
  final String stepText;
  final int stepIndex;
  final int totalSteps;
  final VoidCallback? onTimerFinished;

  const CookingStepView({
    super.key,
    required this.stepText,
    required this.stepIndex,
    required this.totalSteps,
    this.onTimerFinished,
  });

  @override
  State<CookingStepView> createState() => _CookingStepViewState();
}

class _CookingStepViewState extends State<CookingStepView>
    with TickerProviderStateMixin {
  Timer? _stepTimer;
  int _remainingSeconds = 0;
  bool _isTimerRunning = false;
  int _timerInitialDuration = 0;
  Duration? _detectedDuration;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _detectedDuration = _parseDurationFromText(widget.stepText);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pulseController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _pulseController.forward();
      }
    });
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // --- LOGIKA ANIMASI SIMPEL (SATU BUAT SEMUA) ---
  // Kita pake satu link animasi Chef yang paling stabil & umum.
  // Gak perlu if-else ribet, yang penting visualnya "Masak".
  String _getGenericAnimation() {
    // Animasi Chef lagi masak di wajan (Happy Chef) - Asset Public Stabil
    return 'https://assets2.lottiefiles.com/packages/lf20_jbt4j3ea.json';
  }
  // ---------------------------------------------

  Duration? _parseDurationFromText(String text) {
    final regex = RegExp(
        r'(\d+)\s*(menit|jam|detik|minute|minutes|hour|hours|second|seconds)',
        caseSensitive: false);
    final match = regex.firstMatch(text);

    if (match != null) {
      int value = int.parse(match.group(1)!);
      String unit = match.group(2)!.toLowerCase();
      if (unit.contains('jam') || unit.contains('hour')) return Duration(hours: value);
      if (unit.contains('menit') || unit.contains('minute')) return Duration(minutes: value);
      return Duration(seconds: value);
    }
    return null;
  }

  void _startTimer(Duration duration) {
    _stepTimer?.cancel();
    _pulseController.forward();
    setState(() {
      _timerInitialDuration = duration.inSeconds;
      _remainingSeconds = duration.inSeconds;
      _isTimerRunning = true;
    });
    _stepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _stopTimerLogic();
            timer.cancel();
            _playTimerAlarm();
          }
        });
      }
    });
  }

  void _cancelTimer() {
    _stepTimer?.cancel();
    _stopTimerLogic();
    if (mounted) setState(() => _remainingSeconds = 0);
  }

  void _stopTimerLogic() {
    _pulseController.stop();
    _pulseController.reset();
    setState(() => _isTimerRunning = false);
  }

  void _playTimerAlarm() {
    widget.onTimerFinished?.call();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.timer_off, color: Colors.redAccent, size: 30),
            SizedBox(width: 10),
            Text("Waktu Habis!", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text("Langkah ini sudah selesai. Yuk lanjut!", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Siap!", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Color _getProgressColor(double percent) {
    if (percent > 0.5) return Colors.greenAccent;
    if (percent > 0.2) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  String _formatTime(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return "${d.inHours} Jam";
    if (d.inMinutes > 0) return "${d.inMinutes} Menit";
    return "${d.inSeconds} Detik";
  }

  @override
  Widget build(BuildContext context) {
    final animationUrl = _getGenericAnimation();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          const SizedBox(height: 20), 
          
          // --- 1. BADGE LANGKAH (DIPAKU DI ATAS) ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
              ]
            ),
            child: Text(
              "LANGKAH ${widget.stepIndex + 1}",
              style: const TextStyle(
                color: Colors.greenAccent, 
                fontWeight: FontWeight.bold, 
                fontSize: 14, 
                letterSpacing: 1.5
              ),
            ),
          ),

          // --- 2. KONTEN UTAMA (SCROLLABLE) ---
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 30), 

                    // --- ANIMASI / VISUAL ---
                    // Hanya muncul kalau timer lagi MATI
                    if (!_isTimerRunning) 
                      Container(
                        // KUNCI: Pake SizedBox dengan tinggi tetap biar layout gak goyang
                        height: 250, 
                        width: 250,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: Lottie.network(
                            animationUrl,
                            fit: BoxFit.cover,
                            // Kalau masih gagal juga, kita tampilin icon masak yang GEDE
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.transparent,
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.soup_kitchen_rounded, size: 80, color: Colors.white.withOpacity(0.5)),
                                    const SizedBox(height: 8),
                                    Text(
                                      "Siap Masak!", 
                                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.bold)
                                    )
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                    // --- TEKS LANGKAH ---
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: Text(
                        widget.stepText,
                        key: ValueKey(widget.stepText),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 20, 
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            height: 1.6),
                      ),
                    ),
                    
                    // --- TIMER SECTION ---
                    if (_detectedDuration != null) ...[
                      const SizedBox(height: 40),
                      if (_isTimerRunning) ...[
                        // Timer Jalan (Visual Gede)
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(width: 200, height: 200,
                                child: CircularProgressIndicator(value: 1.0, strokeWidth: 12, valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.withOpacity(0.2))),
                              ),
                              SizedBox(width: 200, height: 200,
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween<double>(begin: 1, end: _remainingSeconds / _timerInitialDuration),
                                  duration: const Duration(seconds: 1),
                                  curve: Curves.linear,
                                  builder: (context, value, _) {
                                    return CircularProgressIndicator(value: value, strokeWidth: 12, valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor(value)), strokeCap: StrokeCap.round);
                                  },
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_formatTime(_remainingSeconds), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'monospace', letterSpacing: 2)),
                                  const Text("SISA WAKTU", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        OutlinedButton.icon(onPressed: _cancelTimer, icon: const Icon(Icons.stop_circle_outlined, color: Colors.redAccent, size: 24), label: const Text("BATALKAN", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1)), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: const StadiumBorder()))
                      ] else ...[
                        // Tombol Mulai Timer
                        Container(
                          margin: const EdgeInsets.only(top: 30),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.grey[800]!, Colors.grey[900]!], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))], border: Border.all(color: Colors.white10)),
                          child: Column(
                            children: [
                              Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.timer, color: Colors.blueAccent), const SizedBox(width: 8), const Text("TIMER TERDETEKSI", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1))]),
                              const SizedBox(height: 12),
                              Text(_formatDuration(_detectedDuration!), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                              const SizedBox(height: 12),
                              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => _startTimer(_detectedDuration!), style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 5), child: const Text("MULAI HITUNG MUNDUR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)))),
                            ],
                          ),
                        )
                      ]
                    ],
                    const SizedBox(height: 40), 
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