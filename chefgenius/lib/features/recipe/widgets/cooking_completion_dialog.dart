import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../app/config/chef_cei_assets.dart'; // Import Aset Chef Cei

class CookingCompletionDialog extends StatefulWidget {
  final VoidCallback onClose;

  const CookingCompletionDialog({super.key, required this.onClose});

  @override
  State<CookingCompletionDialog> createState() => _CookingCompletionDialogState();
}

class _CookingCompletionDialogState extends State<CookingCompletionDialog> {
  // NERF & BUFF: Teksnya kita bikin jujur +50 XP sesuai backend
  final int _displayEarnedXp = 50; 
  
  int _currentTotalXp = 0;
  int _currentLevel = 0;
  bool _isLoading = true;

  // KONSTANTA LEVEL (Udah disamain sama Pantry: 300)
  static const int xpPerLevel = 300; 

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // PERBAIKAN PENTING:
    // Kita cuma BACA ('get') data di sini. 
    // Penambahan XP +50 sebenernya udah dilakuin di 'cooking_mode_screen.dart' 
    // SEBELUM dialog ini muncul. Jadi nilai 'user_xp' di sini udah nilai TERBARU.
    int savedXp = prefs.getInt('user_xp') ?? 0;
    
    if (mounted) {
      setState(() {
        _currentTotalXp = savedXp;
        _currentLevel = _currentTotalXp ~/ xpPerLevel;
        _isLoading = false;
      });
    }
    
    // HAPUS kode 'setInt' di sini biar XP gak nambah dua kali (Double Dip)!
  }

  String _getChefTitle(int level) {
    if (level < 2) return "Anak Kos (Newbie)";
    if (level < 5) return "Koki Rumahan";
    if (level < 10) return "Chef Handal";
    if (level < 20) return "Sous Chef"; 
    return "Master Chef";
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox.shrink();

    final title = _getChefTitle(_currentLevel);

    // Hitung progress bar (Logika Pantry)
    // Rumus: (Total XP - XP Dasar Level Ini) / 300
    // Contoh: Level 1 (Start 300). Total 565. Sisa 265. Progress 265/300.
    int currentLevelBaseXp = _currentLevel * xpPerLevel;
    
    // XP yang didapet di level berjalan ini (Sisa XP)
    int xpInCurrentLevel = _currentTotalXp - currentLevelBaseXp;
    
    double progress = xpInCurrentLevel / xpPerLevel;

    // Safety check biar bar gak bablas
    if (progress > 1.0) progress = 1.0;
    if (progress < 0.0) progress = 0.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amber, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- UPDATE: PAKE GAMBAR CHEF CEI BERHASIL ---
                ClipOval(
                  child: Container(
                    color: Colors.amber.withOpacity(0.2),
                    child: Image.asset(
                      ChefCeiAssets.berhasil, // Gambar Chef Cei
                      height: 120,
                      width: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // -------------------------------------------

                const SizedBox(height: 16),
                const Text(
                  "Resep Selesai! 🍳",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  "Kerja bagus! Kamu dapet +$_displayEarnedXp XP",
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                
                // Stats Card dengan Progress Bar Detail
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           Text("Level $_currentLevel", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amber)),
                           // Tampilkan Format Pantry: "265 / 300 XP" (Bukan total akumulasi)
                           Text("$xpInCurrentLevel / $xpPerLevel XP", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: Colors.grey[300],
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Title: $title",
                        style: const TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: widget.onClose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 12),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text("Lanjut Masak!"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}